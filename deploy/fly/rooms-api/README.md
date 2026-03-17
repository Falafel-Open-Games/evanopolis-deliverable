# Fly.io Rooms API

This folder contains a Docker-first Fly.io staging path for the
`apps/rooms-api` service.

## What It Deploys

- the existing `deploy/docker/rooms-api/Dockerfile`
- one public HTTPS endpoint on `https://<app-name>.fly.dev/`
- the same runtime contract used locally:
  - required `AUTH_BASE_URL`
  - optional `AUTH_VERIFY_PATH` (defaults to `/whoami`)
  - optional `ROOMS_DATA_FILE` for JSON-file persistence
  - `PORT`, fixed to `3001` in Fly unless `internal_port` also changes

## Required Setup

Install `flyctl`, authenticate, and create the app once:

```bash
fly auth login
fly apps create <app-name>
```

Deploy with an explicit app name:

```bash
fly deploy -c deploy/fly/rooms-api/fly.toml -a <app-name>
```

## Runtime Configuration

GitHub is the intended source of truth for Fly runtime configuration.

Repository settings expected by the deploy workflow:

- secret `FLY_API_TOKEN`
- variable `FLY_ROOMS_API_APP`
- variable `AUTH_BASE_URL`
- variable `AUTH_VERIFY_PATH`
- variable `ROOMS_API_PORT`
- variable `ROOMS_API_DATA_FILE`

The workflow in
[`rooms-api-fly-deploy.yml`](../../../.github/workflows/rooms-api-fly-deploy.yml)
syncs those values into Fly with `flyctl secrets set` before each deploy.

## CI/CD Behavior

The deploy workflow is intentionally separate from the image-publish workflow:

- `.github/workflows/rooms-api-image.yml` publishes GHCR and Docker Hub images
- `.github/workflows/rooms-api-fly-deploy.yml` builds from the checked-in
  Dockerfile with `flyctl deploy --remote-only`

For a one-time bootstrap or manual recovery, you can still set values directly:

```bash
fly secrets set AUTH_BASE_URL=https://<auth-host> -a <app-name>
fly secrets set ROOMS_DATA_FILE=/data/rooms.json -a <app-name>
```

Optional override:

```bash
fly secrets set AUTH_VERIFY_PATH=/whoami -a <app-name>
```

If you want room definitions to survive deploys or restarts, create and attach a
Fly volume and point `ROOMS_DATA_FILE` at that mounted path. Otherwise the API
works in ephemeral mode and room records reset on fresh machines.

## Health Checks

The Fly config uses one built-in HTTP readiness check:

- `GET /healthz`

For manual verification after deploy:

```bash
./deploy/fly/rooms-api/smoke-check.sh https://<app-name>.fly.dev/
```
