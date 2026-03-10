# Evanopolis Deliverable Monorepo

This repo is the consolidation target for the final deliverable.

The auth service is the exception: by client requirement, its implementation
stays private in the separate `tabletop-auth` repository and is treated here as
an external dependency.

It is intentionally organized around the production pieces that need to be tested, deployed, and handed over clearly:

- `apps/auth-server/` - public integration stub and runbook for the private auth service repo
- `apps/game-server/` - Godot headless multiplayer server and rules runtime
- `apps/web-wrapper/` - HTML/web flow for room creation, invitation handling, and game launch
- `apps/text-client/` - text-only client kept only as a testing/support tool
- `apps/graphical-client/` - final graphical client
- `deploy/` - Docker, Compose, AWS, and staging deployment assets
- `docs/` - architecture, migration notes, runbooks, and wrap-up plan
- `tests/` - cross-app integration and environment validation docs/scripts

## Current Migration Strategy

This migration starts with the server pieces first:

1. keep auth-server private in `../tabletop-auth` and document how this repo integrates with it
2. consolidate game-server from `../evanopolis-ui-slice/godot2`
3. make local Docker/Compose boot the public repo plus the private auth dependency
4. add CI plus automatic staging deploy
5. bring in the web wrapper for room creation, invitations, and launch flow
6. bring in clients only after the server stack is stable

### Graphical Client Migration Note

The final graphical client should reuse the approved UI from the offline demo source in `../evanopolis-ui-slice/godot`.

That migration is not a greenfield rewrite. It is an adaptation effort:

- preserve the approved UI and interaction patterns where possible
- replace offline/local game logic with multiplayer RPC-driven flow
- keep the server as the authoritative source of match state

## Source Repos

- Private auth source: `../tabletop-auth`
- Game server source: `../evanopolis-ui-slice/godot2`
- Offline UI/client source: `../evanopolis-ui-slice/godot`

## Delivery Standard

Every folder in this repo should answer three questions quickly:

1. What is this piece for?
2. How do I run and test it locally?
3. What still needs to be migrated or hardened?

If a folder does not answer those clearly, it is not ready.
