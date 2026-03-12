# Rooms API

## Purpose

This app is the canonical REST surface for room creation and room definition
lookup.

In the current architecture:

- `web-wrapper` creates rooms here
- `game-server` reads room definitions here on first authenticated join
- `game-server` remains authoritative for live match state and gameplay

## Contract

The canonical REST contract is documented in [REST_API.md](./REST_API.md).

## Initial Scope

- authenticated `POST /v0/rooms`
- minimal `GET /v0/rooms/:game_id`
- no public room listing
- no matchmaking
- no live match status
- no persistence assumptions beyond what the implementation later chooses

## Relationship To `game-server`

- `rooms-api` owns room definitions
- `game-server` lazily instantiates an in-memory match from a room definition
  when the first authenticated player joins with a valid `game_id`
- `game-server` should not depend on `rooms-api` for turn state, ready state,
  or other live match data
