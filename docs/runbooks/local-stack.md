# Local Stack Runbook

This is the current local path for running the public repo against the sibling
private auth repo.

It is intentionally narrow. The goal is one obvious local boot path for:

- private auth from `../tabletop-auth`
- `rooms-api`
- `game-server`
- `web-wrapper`

## Terminal 1: Auth Server

From the sibling private repo:

```bash
cd ../tabletop-auth
just dev
```

Current expected local auth endpoint:

```text
http://localhost:3000
```

## Terminal 2: Auth Tunnel

From the same private repo:

```bash
cd ../tabletop-auth
just tunnel
```

Current expected tunneled auth endpoint:

```text
https://tabletop-demo-auth.falafel.com.br
```

For the local stack described below, prefer the plain local auth API on port
`3000`. The demo UI on `8000` is useful for auth-repo-specific testing, but it
is not the API target for this wrapper.

## Terminal 3: Rooms API

From this repo:

```bash
cd apps/rooms-api
AUTH_BASE_URL=http://127.0.0.1:3000 npm run dev
```

Expected endpoint:

```text
http://127.0.0.1:3001
```

## Terminal 4: Game Server

From this repo:

```bash
cd apps/game-server
AUTH_BASE_URL=http://127.0.0.1:3000 \
ROOMS_API_BASE_URL=http://127.0.0.1:3001 \
just run
```

Expected endpoint:

```text
ws://127.0.0.1:9010
```

## Terminal 5: Web Wrapper

From this repo:

```bash
cd apps/web-wrapper
cp .env.example .env.local
npm run dev
```

The checked-in `.env.example` is aligned with the local stack above:

- `VITE_AUTH_BASE_URL=http://127.0.0.1:3000`
- `VITE_ROOMS_BASE_URL=http://127.0.0.1:3001`
- `VITE_GAME_SERVER_URL=ws://127.0.0.1:9010`

During `npm run dev`, the wrapper now uses Vite same-origin proxies for auth
and rooms by default. That avoids local browser CORS failures against
`localhost:3000` and `localhost:3001`.

Expected local wrapper URL:

```text
http://127.0.0.1:5173/
```

Prefer the localhost wrapper for the main local flow. The tunneled wrapper
origin is useful later, but it introduces HTTPS and cross-origin constraints
that are separate from getting the stack locally runnable.

## Quick Validation

Use this order:

1. Open `http://127.0.0.1:5173/`.
2. Connect the wallet and complete auth.
3. Create a room through the wrapper.
4. Copy and open the generated invite.
5. Confirm the invite page can load the room definition from `rooms-api`.
6. Confirm the launch step carries the expected `game_id`, token, and game
   server URL.

## Fast Repo Checks

From the repo root:

```bash
just test
```

This currently runs:

- `apps/rooms-api` Vitest coverage
- `apps/game-server` GUT coverage with an explicit log-file override

The explicit `/tmp/...` log-file override is required because the default
Godot log path crashes in this environment before the suite starts.
