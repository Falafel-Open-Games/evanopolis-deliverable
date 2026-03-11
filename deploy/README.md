# Deploy

This folder will hold the deployment assets for the consolidated public stack
and its integration points with the private auth service.

## Intended Contents

- `docker/` for app Dockerfiles and shared container notes
- `aws/` for EC2/systemd/bootstrap notes
- `staging/` for Fly.io or AWS staging deployment references

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

Local run example:

```bash
docker run --rm -p 9010:9010 \
  -e AUTH_BASE_URL=http://host.docker.internal:3000 \
  evanopolis-game-server
```

On Linux, add `--add-host=host.docker.internal:host-gateway` if the auth server
is running on the host machine.

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
