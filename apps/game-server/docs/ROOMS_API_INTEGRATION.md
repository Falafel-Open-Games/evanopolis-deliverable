# Game Server Room Dependency

The canonical room creation REST contract now lives in
[`apps/rooms-api/REST_API.md`](../../rooms-api/REST_API.md).

This document describes how `apps/game-server` depends on that API.

## Responsibility Split

- `rooms-api` owns room definitions keyed by `game_id` and is the intended
  durable store for finished-match result records
- `game-server` owns live in-memory matches, runtime player connectivity, ready
  state, gameplay authority, and authoritative winner determination
- `game-server` should not own the public room creation HTTP surface

## Expected Join Flow

1. A client connects to the game server over WebSocket and sends `rpc_auth`.
2. The game server verifies the JWT with the auth service using `/whoami`.
3. When the client attempts `rpc_join(game_id, player_id)`, the game server
   looks up the room definition by `game_id`.
4. If the room definition exists and no live match is loaded yet, the game
   server creates the in-memory match from that definition.
5. The game server proceeds with normal authoritative join and gameplay flow.
6. When the match ends authoritatively, the game server should persist a final
   result record to `rooms-api` keyed by the same `game_id`.

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

The intended additional dependency is:

- durable persistence of an already-decided finished-match result after the
  authoritative gameplay runtime ends the match

## Payment / Admission Boundary

- Payment should be enforced when players participate in a match, not when a
  room definition is created.
- The game server remains the component that applies admission rules at join
  time, using auth and payment dependencies as needed.

## Finished-Match Result Boundary

- The game server should remain the only component that decides:
  - whether the match has ended
  - who won
  - why the match ended
  - what the final authoritative tallies are
- The rooms API should persist and serve that final result after the decision
  has already been made.
- Sponsor/operator APIs should consult the durable result record in `rooms-api`
  rather than interrogating live in-memory gameplay state.

## Deployment Constraint

- In the current `v0` direction, room definitions may outlive a game-server
  process restart, while live matches do not.
- The game server should therefore be able to recreate a live match lazily from
  the room definition after restart or reconnect.
