# Local Stack Runbook

This is the current local path for running the public repo against the sibling
private auth repo.

It is intentionally narrow. The goal is one obvious local boot path for:

- private auth from `../tabletop-auth`
- `rooms-api`
- `game-server`
- `web-wrapper`

## Optional Preinstall

From this repo:

```bash
just install
```

That preinstalls the Node dependencies used by `rooms-api` and
`web-wrapper`.

If you skip this step, `just dev` will install those app dependencies on first
run with `npm ci`.

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

Confirm the auth API is actually up before starting the public stack:

```bash
curl http://127.0.0.1:3000/health
```

Expected response:

```json
{"ok":true}
```

## Optional: Auth Tunnel

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

## Terminal 2: Public Stack

From this repo:

```bash
just dev
```

This root recipe does three things:

- uses local `godot` for `apps/game-server` when available, including the
  one-time import on fresh clones
- otherwise falls back to the checked-in Docker game-server path
- starts `rooms-api` on `http://127.0.0.1:3001` against the local auth API
- persists local room definitions to `${ROOMS_DATA_FILE:-$HOME/.evanopolis/rooms.json}`
- starts `game-server` and `web-wrapper` with the local defaults

Expected endpoints:

```text
http://127.0.0.1:3001
ws://127.0.0.1:9010
http://127.0.0.1:5173/
```

During `npm run dev`, the wrapper now uses Vite same-origin proxies for auth
and rooms by default. That avoids local browser CORS failures against
`localhost:3000` and `localhost:3001`.

Prefer the localhost wrapper for the main local flow. The tunneled wrapper
origin is useful later, but it introduces HTTPS and cross-origin constraints
that are separate from getting the stack locally runnable.

## Manual Service Recipes

If you need to isolate one service, the root `justfile` still exposes:

- `just dev-rooms`
- `just dev-game`
- `just dev-wrapper`

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
