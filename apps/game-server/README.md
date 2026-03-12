# Game Server

Canonical source migrated from: `../evanopolis-ui-slice/godot2`

## Purpose

This app is the authoritative multiplayer runtime for the public deliverable
repo.

It currently contains:

- the Godot headless server entrypoint
- the rules engine and match state logic
- GUT-based tests for match flow, reconnect, incidents, inspection, and auth integration points
- demo match configs for local bring-up
- the canonical RPC contract in `RPC_API.md`

## Local Run

Work from this directory:

```bash
cd apps/game-server
```

On a fresh clone, import the project once:

```bash
just import
```

Run the headless server:

```bash
just run
```

`AUTH_BASE_URL` is required at startup. For local auth integration with the
private sibling repo:

```bash
AUTH_BASE_URL=http://127.0.0.1:3000 just run
```

Useful overrides:

- `-- --port 9010`
- `-- --config res://configs/demo_001.toml`
- `-- --config-dir res://configs`
- `-- --auth-base-url http://127.0.0.1:3000`
- `-- --auth-verify-path /whoami`

If `AUTH_BASE_URL` or `AUTH_VERIFY_PATH` are not provided on the command line,
the server also reads them from `.env`.

## Docker Run

Build the image from this directory:

```bash
just docker-build
```

Prebuilt images are also published automatically on each push to `main`:

- `ghcr.io/falafel-open-games/evanopolis-game-server:latest`
- `docker.io/fczuardi/evanopolis-game-server:latest`

Anonymous pull examples:

```bash
docker pull ghcr.io/falafel-open-games/evanopolis-game-server:latest
docker pull docker.io/fczuardi/evanopolis-game-server:latest
```

Run the Dockerized server against a local auth service on Linux:

```bash
AUTH_BASE_URL=http://127.0.0.1:3000 just docker-run
```

The `docker-run` recipe uses `--network host`, which keeps local auth lookups
simple and avoids `host.docker.internal` issues on Linux.

## Fly.io Staging Deploy

Fly.io deployment assets live under
[deploy/fly/game-server/](../../deploy/fly/game-server/README.md).

Basic flow:

```bash
fly apps create <app-name>
fly secrets set AUTH_BASE_URL=https://<auth-host> -a <app-name>
fly deploy -c deploy/fly/game-server/fly.toml -a <app-name>
```

For ongoing staging sync from `main`, use the GitHub Actions workflow in
`.github/workflows/game-server-fly-deploy.yml` and keep the Fly app/runtime
values in GitHub repository settings.

The public WebSocket endpoint is:

```text
wss://<app-name>.fly.dev/
```

After deploy, verify health and the WebSocket upgrade path:

```bash
fly checks list -a <app-name>
./deploy/fly/game-server/smoke-check.sh https://<app-name>.fly.dev/
```

## Test

Run the suite from this directory:

```bash
just test
```

If GUT reports missing imported class names, rerun the one-time import command above.

## RPC Contract

The canonical RPC surface is documented in [RPC_API.md](./RPC_API.md).

That file should stay aligned with:

- `scripts/headless_rpc.gd` for the shared method surface
- `scripts/server_main.gd` for server-side handling
- `tests/` for behavioral guarantees

## Implementation Notes

- The full `godot2` project was copied as the first safe slice because the test suite still depends on shared client-side support scripts such as `scripts/client.gd`.
- `scenes/client_main.tscn` and related scripts are support code for tests and diagnostics, not the main deliverable runtime.
- Auth is external to this repo. The server expects an auth service that can verify bearer tokens and return a `/whoami` payload with at least a stable `sub`.
- `AUTH_BASE_URL` and `AUTH_VERIFY_PATH` control that auth integration.

## Remaining Work

- add a documented local stack path with the private auth service
- trim or separate non-essential support code once server coverage is preserved
