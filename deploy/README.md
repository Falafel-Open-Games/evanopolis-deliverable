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
- rooms-api
- web-wrapper
- private auth-service integration

## Current Docker Assets

`deploy/docker/game-server/Dockerfile` builds a portable headless Godot image for
`apps/game-server/`.

`deploy/docker/rooms-api/Dockerfile` builds a lightweight Node image for
`apps/rooms-api/`.

`deploy/docker/web-wrapper/Dockerfile` builds a static wrapper image and serves
it through nginx with runtime config injected at container startup.

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

For the rooms API, build from the repo root with:

```bash
docker build -f deploy/docker/rooms-api/Dockerfile -t evanopolis-rooms-api .
```

Run it against a local auth service:

```bash
docker run --rm -it --init --network host \
  -e AUTH_BASE_URL=http://127.0.0.1:3000 \
  -e AUTH_VERIFY_PATH="${AUTH_VERIFY_PATH:-/whoami}" \
  -e PORT="${ROOMS_API_PORT:-3001}" \
  -e ROOMS_DATA_FILE="${ROOMS_DATA_FILE:-}" \
  evanopolis-rooms-api
```

For the web wrapper, build from the repo root with:

```bash
docker build -f deploy/docker/web-wrapper/Dockerfile -t evanopolis-web-wrapper .
```

Run it with runtime config injected on startup:

```bash
docker run --rm -it --init -p 8080:8080 \
  -e AUTH_BASE_URL=http://127.0.0.1:3000 \
  -e ROOMS_BASE_URL=http://127.0.0.1:3001 \
  -e EXPECTED_CHAIN_ID=421614 \
  -e GAME_SERVER_URL=ws://127.0.0.1:9010 \
  -e PAYMENT_TOKEN_ADDRESS=0x422d3188537b3226c9a3cd47647d363fc5e0d727 \
  -e PAYMENT_HANDLER_ADDRESS=0x666711a0e1b300d3ba0e5d9579974ebaf28fecdb \
  -e PAYMENT_ADAPTER_ADDRESS=0x6863896de06241853470205f2df5d6a76f491fe1 \
  evanopolis-web-wrapper
```

## Image Publishing

GitHub Actions workflow `.github/workflows/game-server-image.yml` publishes the
same image to:

- `ghcr.io/<github-owner>/evanopolis-game-server`
- `docker.io/<dockerhub-user>/evanopolis-game-server`

Current public image locations:

- `ghcr.io/falafel-open-games/evanopolis-game-server:latest`
- `docker.io/fczuardi/evanopolis-game-server:latest`

These images are rebuilt and published automatically on pushes to `main`.

GitHub Actions workflow `.github/workflows/rooms-api-image.yml` publishes the
rooms API image to:

- `ghcr.io/<github-owner>/evanopolis-rooms-api`
- `docker.io/<dockerhub-user>/evanopolis-rooms-api`

GitHub Actions workflow `.github/workflows/web-wrapper-image.yml` publishes the
wrapper image to:

- `ghcr.io/<github-owner>/evanopolis-web-wrapper`
- `docker.io/<dockerhub-user>/evanopolis-web-wrapper`

Required repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Fly.io Staging Path

`deploy/fly/game-server/fly.toml` deploys the existing game-server Dockerfile to
Fly.io and exposes the WebSocket service through Fly's HTTP/TLS edge.

`deploy/fly/rooms-api/fly.toml` deploys the rooms API and exposes a standard
HTTPS REST surface.

`deploy/fly/web-wrapper/fly.toml` deploys the static wrapper and serves the
browser entry pages over HTTPS.

Expected runtime configuration:

- required `AUTH_BASE_URL`
- optional `AUTH_VERIFY_PATH` (default `/whoami`)
- optional `ROOMS_API_BASE_URL` for lazy room hydration from `rooms-api`
- optional `ROOMS_API_LOOKUP_TEMPLATE` (default `/v0/rooms/%s`)
- `GAME_SERVER_PORT`, kept at `9010` unless `internal_port` is also changed in the Fly config
- `ROOMS_BASE_URL`, `EXPECTED_CHAIN_ID`, `GAME_SERVER_URL`, and the payment
  contract addresses for the wrapper runtime config

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
- `AUTH_BASE_URL`
- `AUTH_VERIFY_PATH`
- `GAME_SERVER_PORT`
- `ROOMS_API_BASE_URL`
- `ROOMS_API_LOOKUP_TEMPLATE`
- `FLY_ROOMS_API_APP`
- `ALLOWED_ORIGINS`
- `ROOMS_API_PORT`
- `ROOMS_API_DATA_FILE`
- `FLY_WEB_WRAPPER_APP`
- `ROOMS_BASE_URL`
- `EXPECTED_CHAIN_ID`
- `GAME_SERVER_URL`
- `PAYMENT_TOKEN_ADDRESS`
- `PAYMENT_HANDLER_ADDRESS`
- `PAYMENT_ADAPTER_ADDRESS`

Post-deploy checks:

```bash
fly checks list -a <app-name>
./deploy/fly/game-server/smoke-check.sh https://<app-name>.fly.dev/
```

See [deploy/fly/game-server/README.md](fly/game-server/README.md) for the full
staging runbook.

See [deploy/fly/rooms-api/README.md](fly/rooms-api/README.md) for the rooms API
staging runbook.

See [deploy/fly/web-wrapper/README.md](fly/web-wrapper/README.md) for the web
wrapper staging runbook.
