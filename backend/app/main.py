"""Only implemented, unauthenticated public infrastructure endpoints are exposed.

Room transport will be enabled after Supabase JWT verification and persistence exist.
The authoritative room domain is independently executable and tested in rooms.py.
"""

from fastapi import FastAPI

app = FastAPI(title="OPTIMUM", version="0.1.0")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "version": "0.1.0"}


@app.get("/v1/capabilities")
def capabilities() -> dict:
    return {
        "accounts": False,
        "room_transport": False,
        "room_protocol_version": 1,
        "reason": "Supabase authentication and durable room storage are not configured yet.",
    }
