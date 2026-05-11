# Rooms API

## Purpose

This app is the canonical REST surface for room creation, room definition
lookup, and durable match-result lookup.

In the current architecture:

- `web-wrapper` creates rooms here
- `game-server` reads room definitions here on first authenticated join
- `game-server` remains authoritative for live match state and gameplay
- `rooms-api` is the intended persistent home for finished-match result records
  keyed by `game_id`

## Contract

The canonical REST contract is documented in [REST_API.md](./REST_API.md).

The current implementation provides:

- authenticated `POST /v0/rooms`
- public `GET /v0/rooms/:game_id`
- `GET /healthz` for smoke checks

Planned next contract surface:

- internal match-result writes from `game-server`
- sponsor/operator-facing finished-match result lookup by `game_id`

The current room contract includes:

- `creator_display_name` for player-facing invite identity, limited to 32
  characters after trimming
- `entry_fee_tier` and derived `entry_fee_amount` for room-level payment policy
- `player_count` for the intended room size
- optional `experimental.turn_duration_seconds` for test-only timing overrides

The public room lookup response currently returns:

- `game_id`
- `creator_display_name`
- `entry_fee_tier`
- `entry_fee_amount`
- `player_count`
- optional `experimental`
- `created_at`

Planned finished-match result data should include:

- `game_id`
- finished status and `finished_at`
- winner identity for settlement use
- end reason
- duration / turn-count summary
- final standings and relevant end-of-match tallies

## Local Run

Work from this directory:

```bash
cd apps/rooms-api
```

Install dependencies once:

```bash
npm install
```

Run the development server:

```bash
AUTH_BASE_URL=http://127.0.0.1:3000 npm run dev
```

Build and run the production entrypoint:

```bash
AUTH_BASE_URL=http://127.0.0.1:3000 npm run build
AUTH_BASE_URL=http://127.0.0.1:3000 npm start
```

Optional environment variables:

- `PORT` defaults to `3001`
- `AUTH_VERIFY_PATH` defaults to `/whoami`
- `ALLOWED_ORIGINS` controls browser CORS allowlisting
- `ROOMS_DATA_FILE` enables JSON-file persistence when set

Example with local persistence:

```bash
AUTH_BASE_URL=http://127.0.0.1:3000 \
ROOMS_DATA_FILE="$HOME/.evanopolis/rooms.json" \
npm start
```

## Test

Run the test suite:

```bash
npm test
```

## Docker / Deploy Direction

The intended staging path is:

- Docker image built from `deploy/docker/rooms-api/Dockerfile`
- Fly.io app config under `deploy/fly/rooms-api/`
- GitHub Actions publish and deploy workflows triggered on `main`

The Fly deploy workflow now treats `ALLOWED_ORIGINS` as part of the runtime
contract, so staging browser callers should be managed through the repository
variables alongside `AUTH_BASE_URL`.

## Relationship To `game-server`

- `rooms-api` owns room definitions and durable finished-match result records
- `game-server` should lazily instantiate an in-memory match from a room
  definition when the first authenticated player joins with a valid `game_id`
- `game-server` remains authoritative for live match state, winner
  determination, and final authoritative match outcomes
- `game-server` should not depend on `rooms-api` for turn state, ready state,
  or other live match data
- `rooms-api` should not become the authority that decides whether a live match
  is finished; it should persist the authoritative result after `game-server`
  declares it

## Remaining Work

Active delivery tracking now lives in the repo root
[TODO.md](../../TODO.md).

For this app, the live open items are:

- keeping room policy and `entry_fee_amount` aligned with authoritative
  server-side admission enforcement
- defining the durable finished-match result contract that `game-server` will
  write and sponsors/operators will read

For the current repo-level local path, see
[docs/runbooks/local-stack.md](../../docs/runbooks/local-stack.md).
