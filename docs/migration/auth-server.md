# Auth Server Migration Checklist

Source repo: `../tabletop-auth`

Status: keep private and external to this public repository.

## Keep In The Private Repo

- application source
- package manifests and lockfile
- Dockerfile
- docker compose dependencies that are still relevant
- `.github/workflows`
- auth docs that describe API, threat model, and deploy steps

## Mirror Publicly Only As Needed

- API contract summaries that other apps depend on
- non-sensitive local wiring instructions
- deploy integration expectations for the public stack
- manual validation steps for auth-to-game handoff

## Keep If Still True

- Redis/Postgres requirements
- JWT/JWKS flow
- wallet signing flow
- Fly.io deploy setup if it remains the fastest staging path

## Do Not Copy Into This Repo

- implementation source
- secrets or secret-shaped examples
- sensitive operator runbooks
- private CI details that do not belong in a public repo

## Validation From This Repo

- boot auth locally from the sibling private checkout
- verify `/whoami`
- verify wallet sign-in flow
- verify token handoff into the game-server flow
