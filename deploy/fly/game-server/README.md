# Fly.io Game Server

This folder contains a Docker-first Fly.io staging path for the headless
`apps/game-server` service.

## What It Deploys

- the existing `deploy/docker/game-server/Dockerfile`
- one public WebSocket endpoint on `wss://<app-name>.fly.dev/`
- the same runtime contract used locally:
  - required `AUTH_BASE_URL`
  - optional `AUTH_VERIFY_PATH` (defaults to `/whoami`)
  - `GAME_SERVER_PORT`, fixed to `9010` in Fly unless you also change `internal_port`

## Required Setup

Install `flyctl`, authenticate, and create the app once:

```bash
fly auth login
fly apps create <app-name>
```

The checked-in config is portable. Deploy with an explicit app name:

```bash
fly deploy -c deploy/fly/game-server/fly.toml -a <app-name>
```

If you do not want the default region in
[`fly.toml`](fly.toml),
override it at deploy time:

```bash
fly deploy -c deploy/fly/game-server/fly.toml -a <app-name> -r <region>
```

If the app was first created in another region, changing `primary_region` later
does not move the existing machine automatically. In that case, clone the
healthy machine into the new region and then destroy the old one:

```bash
fly machine clone <source-machine-id> --region <region> -a <app-name>
fly machine destroy <old-machine-id> --force -a <app-name>
```

## Runtime Configuration

GitHub is the intended source of truth for Fly runtime configuration.

Repository settings expected by the deploy workflow:

- secret `FLY_API_TOKEN`
- variable `FLY_GAME_SERVER_APP`
- variable `AUTH_BASE_URL`
- variable `AUTH_VERIFY_PATH`
- variable `GAME_SERVER_PORT`

The workflow in
[`game-server-fly-deploy.yml`](../../../.github/workflows/game-server-fly-deploy.yml)
syncs those values into Fly with `flyctl secrets set` before each deploy.

## CI/CD Behavior

The deploy workflow is intentionally separate from the image-publish workflow:

- `.github/workflows/game-server-image.yml` publishes GHCR and Docker Hub images
- `.github/workflows/game-server-fly-deploy.yml` builds from the checked-in
  Dockerfile with `flyctl deploy --remote-only`
- after deploy, the workflow enforces `count = 1` in `iad` with
  `flyctl scale count 1 --region iad --max-per-region 1`

That means Fly staging does not wait for the registry publish job and does not
pull from GHCR or Docker Hub during deploy. Both workflows should stay aligned
to the same Dockerfile and app sources.

This is the current safeguard that keeps the in-memory game server on a single
active machine by default.

For a one-time bootstrap or manual recovery, you can still set them directly:

Set the auth service URL before the first deploy:

```bash
fly secrets set AUTH_BASE_URL=https://<auth-host> -a <app-name>
```

Optional overrides:

```bash
fly secrets set AUTH_VERIFY_PATH=/whoami -a <app-name>
```

`AUTH_BASE_URL` is the only required runtime value. `AUTH_VERIFY_PATH` already
has a default in the Fly config and Docker image. Leave `GAME_SERVER_PORT` at
`9010` unless you also update
[`fly.toml`](fly.toml)
to keep `internal_port` aligned.

## Health Checks

The Fly config uses one built-in readiness check:

- a service-level TCP check on port `9010` for routing readiness

For protocol-level verification, use the repo smoke check after deploy. That
WebSocket upgrade test is kept as a manual validation step because it is more
reliable than Fly's deploy-time machine check for this startup pattern.

## Post-Deploy Verification

Confirm Fly sees the service as healthy:

```bash
fly checks list -a <app-name>
```

Run the repo smoke check against the public endpoint:

```bash
./deploy/fly/game-server/smoke-check.sh https://<app-name>.fly.dev/
```

If you want to verify the routed WebSocket URL directly from a client, use:

```text
wss://<app-name>.fly.dev/
```

## Clean-Machine Validation Checklist

Use this after a fresh push to `main`:

1. Confirm `Publish Game Server Image` passed in GitHub Actions.
2. Confirm `Deploy Game Server To Fly.io` passed in GitHub Actions.
3. From a fresh machine or shell, verify anonymous image pulls:

```bash
docker pull ghcr.io/falafel-open-games/evanopolis-game-server:latest
docker pull docker.io/fczuardi/evanopolis-game-server:latest
```

4. Verify Fly health and the WebSocket endpoint:

```bash
fly checks list -a <app-name>
./deploy/fly/game-server/smoke-check.sh https://<app-name>.fly.dev/
```
