# Rooms API REST Contract

This document is the agreed `v0` REST contract baseline for room creation.

Its purpose is to replace reliance on baked-in demo configs with runtime room
creation while keeping the authoritative gameplay runtime in `apps/game-server`.

## Scope

The wrapper needs to create a room, receive a shareable `game_id`, and later
launch players into the Godot game server. The rooms API owns room definitions.
The game server consumes those definitions and creates live in-memory matches on
first authenticated join.

## Goals

- Let the wrapper create a new room through a standalone REST service.
- Return a shareable `game_id` immediately.
- Keep the game server authoritative for live match lifecycle and gameplay.
- Keep the first version compatible with a single in-memory game-server
  machine.
- Freeze a narrow enough `v0` contract that wrapper work and backend work can
  proceed without settling every long-term policy question first.

## Non-Goals

- No public room listing or matchmaking.
- No live match status in the rooms API.
- No dedicated start-match HTTP endpoint in the first version.
- No payment enforcement at room creation time.

## High-Level Architecture

- `auth-server` proves player identity and, later, payment eligibility.
- `rooms-api` creates and returns room definitions keyed by `game_id`.
- `web-wrapper` calls the rooms API to create rooms and look them up by
  `game_id`.
- `game-server` verifies JWTs, then reads the room definition from the rooms
  API and lazily creates a live in-memory match if needed.
- WebSocket RPC remains the gameplay transport after the client connects to the
  game server.

## Proposed Flow

1. The player authenticates in the wrapper and gets a JWT.
2. The wrapper calls `POST /v0/rooms` on the rooms API with that JWT.
3. The rooms API validates the caller, creates a room definition, and returns a
   UUID v4 `game_id`.
4. The wrapper shows a shareable invite link carrying `game_id`.
5. A player connects to the game server over WebSocket and authenticates with
   `rpc_auth`.
6. On first valid join for a `game_id`, the game server calls
   `GET /v0/rooms/:game_id`.
7. If the room exists, the game server creates the live in-memory match and
   then proceeds with normal `rpc_join(game_id, player_id)` handling.

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
  "creator_display_name": "Falafel Host",
  "entry_fee_tier": "average",
  "player_count": 4,
  "experimental": {
    "board_size": 30,
    "turn_duration_seconds": 60
  }
}
```

Notes:
- `creator_display_name` is the player-facing inviter name supplied by the
  wrapper for later invite and join messaging. It must be between 1 and 32
  characters after trimming.
- `entry_fee_tier` selects one of the fixed room fee presets:
  - `cheap` = `0.10 TRT` = `100000000000000000`
  - `average` = `0.50 TRT` = `500000000000000000`
  - `deluxe` = `1.00 TRT` = `1000000000000000000`
- `entry_fee_amount` is derived server-side from the selected fee tier and
  should be treated as the canonical raw token amount for later payment
  verification.
- `player_count` should stay constrained to valid game values.
- `experimental` is optional and should remain disabled or ignored in
  production unless explicitly enabled for testing.
- `created_by` should be derived from JWT `sub`, which is currently the wallet
  address returned by the auth service.

Response:

```json
{
  "game_id": "550e8400-e29b-41d4-a716-446655440000",
  "created_by": "0x0000000000000000000000000000000000000000",
  "creator_display_name": "Falafel Host",
  "entry_fee_tier": "average",
  "entry_fee_amount": "500000000000000000",
  "player_count": 4,
  "experimental": {
    "board_size": 30,
    "turn_duration_seconds": 60
  },
  "created_at": "2026-03-12T18:30:00Z"
}
```

### `GET /v0/rooms/:game_id`

Purpose:
- Return the room definition for a valid `game_id`.
- Support both wrapper invite lookup and game-server lazy match creation.

Request:

```http
GET /v0/rooms/:game_id
```

Response:

```json
{
  "game_id": "550e8400-e29b-41d4-a716-446655440000",
  "creator_display_name": "Falafel Host",
  "entry_fee_tier": "average",
  "entry_fee_amount": "500000000000000000",
  "player_count": 4,
  "experimental": {
    "board_size": 30,
    "turn_duration_seconds": 60
  },
  "created_at": "2026-03-12T18:30:00Z"
}
```

Notes:
- `GET` should stay intentionally dumb in `v0`.
- Do not return live match status here.
- Omit `created_by` from `GET`; the public join flow should use
  `creator_display_name` instead of exposing the creator wallet address.
- `game_id` should be generated as a UUID v4.

## Initial Implementation Baseline

The first implementation pass should assume:

- `POST /v0/rooms` and `GET /v0/rooms/:game_id` are the only required
  endpoints.
- `creator_display_name`, `entry_fee_tier`, and `player_count` are the stable
  room-creation fields.
- `experimental` is optional and may be ignored unless explicitly enabled in
  non-production environments.
- `created_at` is part of the canonical room definition.
- `entry_fee_amount` is part of the canonical room definition and is derived
  from the selected fee tier for downstream payment enforcement.
- `GET /v0/rooms/:game_id` returns only room-definition data, not runtime
  status.
- The game server creates the live in-memory match lazily from the room
  definition on first valid join.

## Match Start Rules

Current direction:

- Keep the existing ready-based start flow on the WebSocket RPC side.
- Treat `player_count` as the intended full room size, not a hard requirement
  that blocks match start.
- Let the room creator start with fewer than `player_count` players once all
  currently joined players are marked ready.

Those rules belong to the game server, not to the rooms API.

## Payment / Entry Gating

Production direction:

- Payment should be a requirement to participate in a game, not a requirement
  to create a room or reserve a `game_id`.
- The rooms API should not enforce payment to create a room.
- The game server should apply payment gating at admission time, aligned with
  `../tabletop-auth`.

## Deferred Questions

- Do we want one room per creator at a time in the first version?
- What is the room expiration policy for idle, unstarted rooms?
- Should `GET /v0/rooms/:game_id` remain unauthenticated long-term?
- Does the wrapper need any additional room-definition fields beyond the
  current `POST` and `GET` responses?
