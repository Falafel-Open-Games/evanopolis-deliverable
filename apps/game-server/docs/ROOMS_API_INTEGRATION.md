# Game Server Room Dependency

The canonical room creation REST contract now lives in
[`apps/rooms-api/REST_API.md`](../../rooms-api/REST_API.md).

This document describes how `apps/game-server` depends on that API.

## Responsibility Split

- `rooms-api` owns room definitions keyed by `game_id`
- `game-server` owns live in-memory matches, runtime player connectivity, ready
  state, and gameplay authority
- `game-server` should not own the public room creation HTTP surface

## Expected Join Flow

1. A client connects to the game server over WebSocket and sends `rpc_auth`.
2. The game server verifies the JWT with the auth service using `/whoami`.
3. When the client attempts `rpc_join(game_id, player_id)`, the game server
   looks up the room definition by `game_id`.
4. If the room definition exists and no live match is loaded yet, the game
   server creates the in-memory match from that definition.
5. The game server proceeds with normal authoritative join and gameplay flow.

## Room Definition Fields Needed By `game-server`

The game server only needs the minimal room definition required to instantiate
the live match:

- `game_id`
- `player_count`
- `experimental.turn_duration_seconds` when present
- `created_at` if room expiration policy later depends on it

The game server should not depend on `rooms-api` for:

- live player counts
- started/finished status
- turn state
- admission state beyond room-definition existence

## Payment / Admission Boundary

- Payment should be enforced when players participate in a match, not when a
  room definition is created.
- The game server remains the component that applies admission rules at join
  time, using auth and payment dependencies as needed.

## Deployment Constraint

- In the current `v0` direction, room definitions may outlive a game-server
  process restart, while live matches do not.
- The game server should therefore be able to recreate a live match lazily from
  the room definition after restart or reconnect.
