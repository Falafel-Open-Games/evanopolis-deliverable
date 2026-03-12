# Deploy

This folder will hold the deployment assets for the consolidated public stack
and its integration points with the private auth service.

## Intended Contents

- `docker/` for app Dockerfiles and shared container notes
- `aws/` for EC2/systemd/bootstrap notes
- `staging/` for Fly.io or AWS staging deployment references
- `fly/` for checked-in Fly.io app configs and smoke checks

## Immediate Goal

Produce one documented local boot path and one documented staging deploy path for:

- game-server
- private auth-service integration

## Current Docker Assets

`deploy/docker/game-server/Dockerfile` builds a portable headless Godot image for
`apps/game-server/`.

The image expects:

- `AUTH_BASE_URL` at runtime
- optional `AUTH_VERIFY_PATH`
- optional `GAME_SERVER_PORT` (defaults to `9010`)

Local build example:

```bash
docker build -f deploy/docker/game-server/Dockerfile -t evanopolis-game-server .
```

Local run example from the repo root:

```bash
docker run --rm -it --init --network host \
  -e AUTH_BASE_URL=http://127.0.0.1:3000 \
  -e AUTH_VERIFY_PATH="${AUTH_VERIFY_PATH:-}" \
  -e GAME_SERVER_PORT="${GAME_SERVER_PORT:-9010}" \
  evanopolis-game-server
```

This matches the Linux-tested local auth path by using `--network host` and
avoids `host.docker.internal` issues. If you are working from
`apps/game-server/`, the equivalent app-level shortcut is `just docker-run`.

## Image Publishing

GitHub Actions workflow `.github/workflows/game-server-image.yml` publishes the
same image to:

- `ghcr.io/<github-owner>/evanopolis-game-server`
- `docker.io/<dockerhub-user>/evanopolis-game-server`

Current public image locations:

- `ghcr.io/falafel-open-games/evanopolis-game-server:latest`
- `docker.io/fczuardi/evanopolis-game-server:latest`

These images are rebuilt and published automatically on pushes to `main`.

Required repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Fly.io Staging Path

`deploy/fly/game-server/fly.toml` deploys the existing game-server Dockerfile to
Fly.io and exposes the WebSocket service through Fly's HTTP/TLS edge.

Expected runtime configuration:

- required `AUTH_BASE_URL`
- optional `AUTH_VERIFY_PATH` (default `/whoami`)
- `GAME_SERVER_PORT`, kept at `9010` unless `internal_port` is also changed in the Fly config

Typical deploy flow:

```bash
fly apps create <app-name>
fly secrets set AUTH_BASE_URL=https://<auth-host> -a <app-name>
fly deploy -c deploy/fly/game-server/fly.toml -a <app-name>
```

GitHub Actions automation is defined in
`.github/workflows/game-server-fly-deploy.yml`. That workflow treats GitHub
repository settings as the source of truth and syncs Fly runtime configuration
before each deploy.

The Fly deploy workflow is separate from `.github/workflows/game-server-image.yml`.
Registry publishing and Fly deploys both trigger from `main`, but the Fly deploy
builds directly from source with `flyctl deploy --remote-only` instead of using
the published registry image. After deploy, the workflow also forces the app
back to one machine in `iad` so the current in-memory room model stays on a
single active runtime by default.

Required GitHub secret:

- `FLY_API_TOKEN`

Required GitHub variables:

- `FLY_GAME_SERVER_APP`
- `GAME_SERVER_AUTH_BASE_URL`
- `GAME_SERVER_AUTH_VERIFY_PATH`
- `GAME_SERVER_PORT`

Post-deploy checks:

```bash
fly checks list -a <app-name>
./deploy/fly/game-server/smoke-check.sh https://<app-name>.fly.dev/
```

See [deploy/fly/game-server/README.md](fly/game-server/README.md) for the full
staging runbook.
