# Fly.io Web Wrapper

This folder contains the Fly.io staging path for `apps/web-wrapper`.

## What It Deploys

- the existing `deploy/docker/web-wrapper/Dockerfile`
- one public HTTPS endpoint on `https://<app-name>.fly.dev/`
- the wrapper as a static multi-page app served by nginx
- runtime config injected at container startup through `/runtime-config.js`

## Required Setup

Install `flyctl`, authenticate, and create the app once:

```bash
fly auth login
fly apps create <app-name>
```

Deploy with an explicit app name:

```bash
fly deploy -c deploy/fly/web-wrapper/fly.toml -a <app-name>
```

## Runtime Configuration

GitHub is the intended source of truth for Fly runtime configuration.

Repository settings expected by the deploy workflow:

- secret `FLY_API_TOKEN`
- variable `FLY_WEB_WRAPPER_APP`
- variable `AUTH_BASE_URL`
- variable `ROOMS_BASE_URL`
- variable `EXPECTED_CHAIN_ID`
- variable `GAME_SERVER_URL`
- variable `PAYMENT_TOKEN_ADDRESS`
- variable `PAYMENT_HANDLER_ADDRESS`
- variable `PAYMENT_ADAPTER_ADDRESS`

The workflow in
[`web-wrapper-fly-deploy.yml`](../../../.github/workflows/web-wrapper-fly-deploy.yml)
syncs those values into Fly with `flyctl secrets set` before each deploy.

## CI/CD Behavior

The deploy workflow is intentionally separate from image publishing:

- `.github/workflows/web-wrapper-image.yml` publishes GHCR and Docker Hub images
- `.github/workflows/web-wrapper-fly-deploy.yml` builds from source with
  `flyctl deploy --remote-only`

## Health Checks

The Fly config uses one built-in HTTP readiness check:

- `GET /healthz`

For manual verification after deploy:

```bash
./deploy/fly/web-wrapper/smoke-check.sh https://<app-name>.fly.dev/
```
