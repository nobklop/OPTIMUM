"""Authoritative, transport-independent Together aggregate.

One lock serializes commands per room. The caller must authenticate `user_id`.
No paths, media bytes, access tokens, or service playback URLs are accepted.
Times are monotonic milliseconds from a server clock injected by the coordinator.
Snapshots expose their server timestamp so clients can estimate the clock offset.
"""

import asyncio
import math
from collections import OrderedDict
from collections.abc import Callable
from dataclasses import dataclass, field


class RoomError(ValueError):
    pass


@dataclass(frozen=True)
class Track:
    recording_id: str
    duration_ms: int

    def __post_init__(self):
        if not self.recording_id or len(self.recording_id) > 200:
            raise RoomError("Invalid recording id")
        if type(self.duration_ms) is not int or not 1 <= self.duration_ms <= 24 * 3600 * 1000:
            raise RoomError("Invalid duration")


@dataclass
class Room:
    owner: str
    clock: Callable[[], float]
    democratic: bool = False
    members: list[str] = field(default_factory=list)
    queue: list[Track] = field(default_factory=list)
    history: list[str] = field(default_factory=list)
    votes: dict[str, set[str]] = field(default_factory=dict)
    playing: bool = False
    position_ms: float = 0
    anchor_ms: float = 0
    revision: int = 0
    _seen: OrderedDict = field(default_factory=OrderedDict, repr=False)
    _lock: asyncio.Lock = field(default_factory=asyncio.Lock, repr=False)

    def __post_init__(self):
        if not self.owner:
            raise RoomError("Owner is required")
        self.members = [self.owner]
        self.anchor_ms = self.clock()

    def position(self, now: float) -> float:
        elapsed = max(0, now - self.anchor_ms) if self.playing else 0
        duration = self.queue[0].duration_ms if self.queue else 0
        return min(duration, self.position_ms + elapsed)

    def snapshot(self) -> dict:
        now = self.clock()
        return {
            "revision": self.revision,
            "server_ms": now,
            "owner": self.owner,
            "members": list(self.members),
            "democratic": self.democratic,
            "playing": self.playing,
            "position_ms": self.position(now),
            "anchor_ms": self.anchor_ms,
            "queue": [vars(t).copy() for t in self.queue],
            "history": list(self.history),
            "votes": {k: len(v) for k, v in self.votes.items()},
        }

    async def join(self, user_id: str) -> dict:
        async with self._lock:
            if not self.owner:
                raise RoomError("Room is closed")
            if not user_id:
                raise RoomError("Member is required")
            if user_id not in self.members:
                if len(self.members) >= 50:
                    raise RoomError("Room is full")
                self.members.append(user_id)
                self.revision += 1
            return self.snapshot()

    async def command(
        self, user_id: str, command_id: str, expected_revision: int, action: str, value=None
    ) -> dict:
        async with self._lock:
            if user_id not in self.members:
                raise RoomError("Not a member")
            if not command_id or len(command_id) > 128:
                raise RoomError("Invalid command id")
            key = (user_id, command_id)
            if key in self._seen:
                return self.snapshot()  # Retry never reapplies a seek/play/next.
            if expected_revision != self.revision:
                raise RoomError("Stale revision; refresh snapshot")
            owner_only = {"mode", "transfer"}
            controls = {"play", "pause", "seek", "next", "reorder"}
            if (
                action in owner_only or (action in controls and not self.democratic)
            ) and user_id != self.owner:
                raise RoomError("Owner permission required")
            now = self.clock()
            if action == "add":
                if not isinstance(value, Track):
                    raise RoomError("A canonical track is required")
                if len(self.queue) >= 500:
                    raise RoomError("Queue is full")
                if any(t.recording_id == value.recording_id for t in self.queue):
                    raise RoomError("Track is already queued")
                self.queue.append(value)
            elif action == "play":
                self._require_track()
                if not self.playing:
                    if self.position(now) >= self.queue[0].duration_ms:
                        self.position_ms = 0
                    self.anchor_ms = now + 500  # Scheduled start; allow clients to prepare.
                    self.playing = True
            elif action == "pause":
                self.position_ms = self.position(now)
                self.anchor_ms = now
                self.playing = False
            elif action == "seek":
                self._require_track()
                if isinstance(value, bool) or not isinstance(value, (int, float)):
                    raise RoomError("Position must be a number")
                if not math.isfinite(value) or not 0 <= value <= self.queue[0].duration_ms:
                    raise RoomError("Position out of range")
                self.position_ms = value
                self.anchor_ms = now
            elif action == "next":
                self._require_track()
                self.history.append(self.queue.pop(0).recording_id)
                self.history = self.history[-200:]
                if len(self.queue) > 1:
                    best = max(
                        range(len(self.queue)),
                        key=lambda i: len(self.votes.get(self.queue[i].recording_id, set())),
                    )
                    self.queue.insert(0, self.queue.pop(best))
                self.votes.clear()
                self.position_ms = 0
                self.anchor_ms = now + 500
                self.playing = self.playing and bool(self.queue)
            elif action == "vote":
                if value not in [t.recording_id for t in self.queue[1:]]:
                    raise RoomError("Vote must target an upcoming track")
                for voters in self.votes.values():
                    voters.discard(user_id)
                self.votes.setdefault(value, set()).add(user_id)
            elif action == "reorder":
                ids = [t.recording_id for t in self.queue]
                if (
                    not isinstance(value, list)
                    or any(not isinstance(i, str) for i in value)
                    or sorted(value) != sorted(ids)
                ):
                    raise RoomError("Reorder must contain each track exactly once")
                if ids and value[0] != ids[0]:
                    raise RoomError("Cannot reorder the playing track")
                by_id = {t.recording_id: t for t in self.queue}
                self.queue = [by_id[i] for i in value]
            elif action == "mode":
                if not isinstance(value, bool):
                    raise RoomError("Mode must be boolean")
                self.democratic = value
            elif action == "transfer":
                if value not in self.members:
                    raise RoomError("New owner must be a member")
                self.owner = value
            elif action == "leave":
                self.members.remove(user_id)
                for voters in self.votes.values():
                    voters.discard(user_id)
                if user_id == self.owner:
                    self.owner = self.members[0] if self.members else ""
            else:
                raise RoomError("Unknown action")
            self.revision += 1
            self._seen[key] = True
            if len(self._seen) > 2048:
                self._seen.popitem(last=False)
            return self.snapshot()

    def _require_track(self):
        if not self.queue:
            raise RoomError("Queue is empty")
