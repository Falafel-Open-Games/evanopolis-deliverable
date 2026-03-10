# Monorepo Shape

## Principles

- Keep the deployable pieces separated by responsibility.
- Keep the root small and readable.
- Prefer boring names over clever names.
- Make test and deploy entrypoints obvious.

## App Boundaries

### `apps/auth-server`
Owns:
- public integration notes for the private auth service
- local wiring expectations for sibling checkouts
- deploy contract notes shared with the rest of the stack

The auth implementation itself stays private in `../tabletop-auth`.

### `apps/game-server`
Owns:
- multiplayer match lifecycle
- rules enforcement
- session/game state
- headless multiplayer runtime

### `apps/web-wrapper`
Owns:
- room creation flow
- invitation/referral link generation
- accept invitation flow
- game start handoff into the graphical client

This is the main HTML/browser shell around the game experience.

### `apps/text-client`
Owns:
- diagnostic client flows
- operator/debug workflows

This is not a production centerpiece. It exists to accelerate testing.

### `apps/graphical-client`
Owns:
- player-facing client
- final UI integration with the server stack

This should start from the approved offline-demo UI and be adapted to server-authoritative multiplayer RPC flow, not redesigned from scratch.

## Shared Infrastructure

### `deploy/`
Owns:
- Dockerfiles
- Compose files
- staging/prod environment docs
- cloud bootstrap references

### `docs/`
Owns:
- migration notes
- runbooks
- architecture notes
- delivery and testing plans
