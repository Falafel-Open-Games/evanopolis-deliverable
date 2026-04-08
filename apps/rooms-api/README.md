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

The current implementation provides:

- authenticated `POST /v0/rooms`
- public `GET /v0/rooms/:game_id`
- `GET /healthz` for smoke checks

The current room contract includes:

- `creator_display_name` for player-facing invite identity, limited to 32
  characters after trimming
- `entry_fee_tier` and derived `entry_fee_amount` for room-level payment policy
- `player_count` for the intended room size

The public room lookup response currently returns:

- `game_id`
- `creator_display_name`
- `entry_fee_tier`
- `entry_fee_amount`
- `player_count`
- optional `experimental`
- `created_at`

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
ROOMS_DATA_FILE=/tmp/evanopolis-rooms.json \
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

- `rooms-api` owns room definitions
- `game-server` should lazily instantiate an in-memory match from a room
  definition when the first authenticated player joins with a valid `game_id`
- `game-server` should not depend on `rooms-api` for turn state, ready state,
  or other live match data

## Remaining Work

- wire `apps/game-server` to fetch room definitions dynamically instead of
  relying only on preloaded TOML configs
- implement admission and payment enforcement against the room definition,
  including `entry_fee_amount`

For the current repo-level local path, see
[docs/runbooks/local-stack.md](../../docs/runbooks/local-stack.md).
