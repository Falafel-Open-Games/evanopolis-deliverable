# Game Server REST API

This document is the agreed `v0` REST contract baseline for the initial room
creation work. Its purpose is to replace reliance on baked-in demo configs with
runtime room creation and give the wrapper a concrete server contract to build
against.

## Scope

The current game server starts with baked-in demo match configs from
`configs/*.toml`. That works for testing, but the deliverable needs a runtime
room-creation flow where a player creates a room, shares a `game_id`, and other
players join the same room.

## Goals

- Let the wrapper create a new room through the game server.
- Return a shareable `game_id` immediately.
- Keep the game server authoritative for room and match lifecycle.
- Keep gameplay on the existing WebSocket RPC surface.
- Keep the first version compatible with a single in-memory game-server machine.
- Freeze a narrow enough `v0` contract that tests and implementation can start
  before every long-term room-policy question is settled.

## Non-Goals

- No persistence across restart or deploy in the first version.
- No public room listing or matchmaking.
- No dedicated start-match HTTP endpoint in the first version.
- No database in the first version.
- No dependency on baked-in demo configs for production room creation.

## High-Level Architecture

- `auth-server` proves identity and, later, payment eligibility.
- `game-server` creates rooms, owns room metadata, and instantiates matches.
- `web-wrapper` calls a room-creation HTTP API on the game server, then launches
  the game client with the returned `game_id`.
- WebSocket RPC remains the gameplay transport after the client connects.

## Proposed Flow

1. The player authenticates in the wrapper and gets a JWT.
2. The wrapper calls `POST /v0/rooms` on the game server with that JWT.
3. The game server validates the caller and creates a new in-memory room.
4. The game server returns a `game_id` and the public WebSocket URL.
5. The wrapper shows a shareable invite link carrying `game_id`.
6. Each client connects over WebSocket, authenticates with `rpc_auth`, and joins
   with `rpc_join(game_id, player_id)`.
7. Match start still happens through the existing ready flow. No separate HTTP
   start endpoint is planned right now.

## Endpoints

### `POST /v0/rooms`

Purpose:
- Create a new room owned by the authenticated caller.

Request:

```http
POST /v0/rooms
Authorization: Bearer <jwt>
Content-Type: application/json
```

```json
{
  "player_count": 4,
  "experimental": {
    "board_size": 30,
    "turn_duration_seconds": 60
  }
}
```

Initial notes:
- `player_count` should stay constrained to valid game values.
- `experimental` is optional and should remain disabled or ignored in
  production unless explicitly enabled for testing.

Response:

```json
{
  "game_id": "550e8400-e29b-41d4-a716-446655440000",
  "created_by": "0x0000000000000000000000000000000000000000",
  "player_count": 4,
  "status": "waiting",
  "ws_url": "wss://evanopolis-game-server.fly.dev/"
}
```

### `GET /v0/rooms/:game_id`

Purpose:
- Let the wrapper verify that a room exists and whether it is still joinable.

Possible response fields:

```json
{
  "game_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "waiting",
  "created_by": "0x0000000000000000000000000000000000000000",
  "joined_player_count": 1,
  "player_count": 4
}
```

## Initial Implementation Baseline

The first implementation pass should assume:

- `POST /v0/rooms` and `GET /v0/rooms/:game_id` are the only REST endpoints
  required for room creation.
- `player_count` is the only stable room-creation field.
- `experimental` is optional and may be ignored unless explicitly enabled in
  non-production environments.
- `created_by` is the authenticated caller identity from JWT `sub`, which is
  currently the wallet address returned by the auth service.
- `status = "waiting"` for a newly created room.
- Room data is in-memory only.
- The room creator may start with fewer than `player_count` joined players once
  the current ready-flow requirements are satisfied.
- Payment gating applies to participation, not room creation.

## In-Memory Data Model

First version room registry entry:

```text
game_id
created_by
created_at
last_activity_at
status
player_count
experimental_settings
connected_players
match_reference
```

Notes:
- `status` can start as `waiting`, then move to `started`, `finished`, or
  `expired`.
- `game_id` should be generated as a UUID v4.
- `match_reference` points to the runtime-created authoritative match object.

## Match Start Rules

Current direction:

- Keep the existing ready-based start flow on the WebSocket RPC side.
- Do not add `POST /rooms/:game_id/start` unless we prove the wrapper needs it.
- Treat `player_count` as the intended full room size, not a hard requirement
  that blocks match start.
- Let the room creator start with fewer than `player_count` players once all
  currently joined players are marked ready.

## Payment / Entry Gating

Production direction:

- Payment should be a requirement to participate in a game, not a requirement
  to create a room or reserve a `game_id`.
- A player should be admitted only if both are true:
  - they have valid auth (`JWT`)
  - they have a valid payment proof for that `game_id`
- The room creator should only need a verified payment if they are also joining
  the match as a player.

Design alignment with `../tabletop-auth`:

- The auth/payment design describes payment as a game admission check, not a
  room-creation check.
- The wrapper pays against a specific `game_id`, then submits proof to the auth
  service for verification.
- The game server should ask the auth/payment service whether a given player is
  eligible to join/start that specific match.
- The on-chain adapter contract emits `GamePlayed(player, amountPaid, ...,
  gameId)` and does not have any concept of room creation or room reservation.
- In the auth/payment design, `gameId` is correlation for payment verification
  and admission. It is not itself proof that a room was created by a paying
  user.

Staging and development direction:

- Add an explicit server-side configuration flag to bypass paid-entry
  enforcement in non-production environments.

Candidate config:

```text
ROOM_JOIN_PAYMENT_MODE=bypass
```

Requirements for the bypass:

- easy to enable in staging/dev
- impossible to confuse with production defaults
- documented in deploy and app runbooks

## Deployment Constraints

- The current Fly staging setup is intentionally single-machine for safety while
  room state stays in memory.
- Room creation must assume that rooms disappear on deploy/restart in the first
  version.
- This limitation should be visible in docs and operator notes.

## Deferred Questions

- Does the wrapper need any additional room fields beyond the current `POST`
  and `GET` responses?
- Do we want one room per creator at a time in the first version?
- What is the room expiration policy for idle, unstarted rooms?
- Should `GET /rooms/:game_id` be public, authenticated, or invite-token based?
