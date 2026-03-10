# Auth Server Migration Checklist

Source repo: `../tabletop-auth`

## Copy First

- application source
- package manifests and lockfile
- Dockerfile
- docker compose dependencies that are still relevant
- `.github/workflows`
- auth docs that describe API, threat model, and deploy steps

## Keep If Still True

- Redis/Postgres requirements
- JWT/JWKS flow
- wallet signing flow
- Fly.io deploy setup if it remains the fastest staging path

## Remove Or Reevaluate

- demo-only files that do not help delivery
- repo-specific clutter that does not belong in the final monorepo
- duplicated deploy notes that should become shared monorepo docs

## Validation After Copy

- install dependencies
- run tests
- boot auth locally
- verify `/whoami`
- verify wallet sign-in flow
