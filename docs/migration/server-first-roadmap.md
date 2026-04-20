# Server-First Migration Roadmap

This document is historical planning context from the initial consolidation
phase.

It is not the active delivery backlog anymore. The current source of truth for
launch blockers, sequencing, and parking-lot items is the repo root
[TODO.md](../../TODO.md).

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

## Current Use

Use this file only to understand the original migration direction and
non-goals. Do not use it as the active task list during delivery week.
