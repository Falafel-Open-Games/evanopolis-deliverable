# Server-First Migration Roadmap

## Goal

Create a production-readable monorepo that prioritizes:

- multiplayer session hosting
- deployability
- real-environment testing

before client polish.

## Phase 1: Consolidate Server Sources

### Auth Server
- Keep the canonical auth API private in `../tabletop-auth`.
- Document the integration contract in `apps/auth-server/` without copying implementation code into this public repo.
- Preserve deploy compatibility with the private auth service while simplifying public integration docs.

### Game Server
- Move the canonical Godot headless server from `../evanopolis-ui-slice/godot2` into `apps/game-server/`.
- Exclude the text-only client from the core runtime migration.
- Keep tests that validate server rules and reconnect/session behavior.

## Phase 2: Make the Stack Runnable

- Add Dockerfiles for the public apps in this repo.
- Add a root `docker-compose.yml` for local integration with a sibling private auth checkout.
- Define one local boot path and one staging boot path only.

## Phase 3: Real Environment Testing

- Deploy staging automatically on each main-branch push.
- Run auth + game server together against a real external URL.
- Test wallet sign-in, session handoff, join flow, reconnect, and at least one full match.

## Phase 4: Client Migration

- Bring in the text client only as a debugging tool.
- Bring in the graphical client only after the server stack is stable enough for focused validation.

## Non-Goals For This First Migration Step

- do not migrate everything at once
- do not preserve old repo layout just because it already exists
- do not optimize for completeness over clarity

## Immediate Next Actions

1. define and document the auth contract against the private `tabletop-auth` repo
2. copy `godot2` server into `apps/game-server/`
3. add root compose file for game + backing services + private auth integration points
4. add one staging deployment workflow
5. add the main web wrapper for room creation, invitation acceptance, and game launch
6. adapt the approved offline-demo UI into the final graphical client using multiplayer RPCs
7. execute the wrap-up test plan in real environments
