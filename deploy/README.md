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
