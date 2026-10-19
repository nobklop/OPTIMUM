import asyncio
import math

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.rooms import Room, RoomError, Track


def run(coro):
    return asyncio.run(coro)


class Clock:
    now = 1000.0

    def __call__(self):
        return self.now


def setup():
    clock = Clock()
    room = Room("alice", clock)
    run(room.command("alice", "add", 0, "add", Track("mbid:one", 180000)))
    return room, clock


def cmd(room, action, value=None, user="alice", command_id=None):
    return run(room.command(user, command_id or str(room.revision), room.revision, action, value))


def test_scheduled_play_pause_seek_and_latency():
    room, clock = setup()
    cmd(room, "play")
    clock.now += 200
    assert room.snapshot()["position_ms"] == 0
    clock.now += 1300
    assert room.snapshot()["position_ms"] == 1000
    cmd(room, "pause")
    clock.now += 700
    assert room.snapshot()["position_ms"] == 1000
    cmd(room, "seek", 42000)
    assert room.snapshot()["position_ms"] == 42000


def test_join_and_reconnect_current_position():
    room, clock = setup()
    cmd(room, "play")
    clock.now += 4500
    state = run(room.join("bob"))
    assert state["position_ms"] == 4000
    revision = room.revision
    assert run(room.join("bob"))["revision"] == revision
    assert room.members == ["alice", "bob"]


def test_permissions_and_transfer():
    room, _ = setup()
    run(room.join("bob"))
    with pytest.raises(RoomError, match="Owner"):
        cmd(room, "play", user="bob")
    cmd(room, "transfer", "bob")
    cmd(room, "play", user="bob")
    assert room.playing
    with pytest.raises(RoomError, match="Not a member"):
        cmd(room, "pause", user="eve")


def test_owner_leaves_without_stopping_others():
    room, _ = setup()
    run(room.join("bob"))
    cmd(room, "play")
    cmd(room, "leave")
    assert room.owner == "bob"
    assert room.playing


def test_democratic_controls_and_single_vote():
    room, _ = setup()
    run(room.join("bob"))
    cmd(room, "mode", True)
    cmd(room, "add", Track("mbid:two", 10000), user="bob")
    cmd(room, "add", Track("mbid:three", 10000))
    cmd(room, "vote", "mbid:three", user="bob")
    cmd(room, "vote", "mbid:three", user="bob")
    assert room.snapshot()["votes"]["mbid:three"] == 1
    cmd(room, "next", user="bob")
    assert room.queue[0].recording_id == "mbid:three"
    assert room.history == ["mbid:one"]


def test_retry_does_not_reapply_and_stale_command_rejected():
    room, clock = setup()
    cmd(room, "play", command_id="play-once")
    clock.now += 2000
    state = run(room.command("alice", "play-once", 1, "play"))
    assert state["position_ms"] == 1500
    with pytest.raises(RoomError, match="Stale"):
        run(room.command("alice", "stale", 1, "pause"))


def test_simultaneous_commands_have_one_winner():
    room, _ = setup()

    async def race():
        return await asyncio.gather(
            room.command("alice", "a", 1, "play"),
            room.command("alice", "b", 1, "seek", 1000),
            return_exceptions=True,
        )

    results = run(race())
    assert sum(isinstance(r, RoomError) for r in results) == 1
    assert room.revision == 2


@pytest.mark.parametrize("value", [-1, 180001, math.nan, math.inf, True, "10"])
def test_invalid_seek_is_atomic(value):
    room, _ = setup()
    before = room.snapshot()
    with pytest.raises(RoomError):
        cmd(room, "seek", value)
    assert room.snapshot() == before


def test_queue_reorder_end_and_snapshot_isolation():
    room, _ = setup()
    cmd(room, "add", Track("mbid:two", 10000))
    with pytest.raises(RoomError):
        cmd(room, "reorder", ["mbid:two", "mbid:one"])
    state = room.snapshot()
    state["queue"][0]["recording_id"] = "corrupted"
    assert room.queue[0].recording_id == "mbid:one"
    cmd(room, "play")
    cmd(room, "next")
    cmd(room, "next")
    assert not room.playing
    assert room.snapshot()["position_ms"] == 0


def test_api_is_honest_and_does_not_expose_unauthenticated_room_mutation():
    async def scenario():
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            assert (await client.get("/health")).json()["status"] == "ok"
            assert (await client.get("/v1/capabilities")).json()["room_transport"] is False
            assert (await client.post("/v1/rooms")).status_code == 404

    run(scenario())


def test_last_member_leaves_room_is_closed():
    room, _ = setup()
    cmd(room, "leave")
    with pytest.raises(RoomError, match="closed"):
        run(room.join("bob"))


def test_invalid_track_and_reorder_do_not_mutate_state():
    with pytest.raises(RoomError):
        Track("one", True)
    room, _ = setup()
    before = room.snapshot()
    with pytest.raises(RoomError):
        cmd(room, "reorder", [1])
    assert room.snapshot() == before
