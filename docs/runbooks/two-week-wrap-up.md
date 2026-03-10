# Two-Week Wrap-Up Plan

This plan is intentionally narrow. The goal is not to build more. The goal is to consolidate, deploy, and validate what already exists in real environments.

## Week 1

### Day 1-2
- Create the monorepo skeleton.
- Migrate `tabletop-auth` into `apps/auth-server/`.
- Migrate `godot2` headless server into `apps/game-server/`.
- Remove obviously stale or duplicate files during migration.

### Day 3
- Add root Docker Compose for local stack:
- auth API
- auth backing services
- headless game server

### Day 4
- Normalize docs:
- one README per app
- one local runbook
- one staging runbook
- one environment variable reference

### Day 5
- Run local end-to-end checks:
- wallet auth
- token verification
- join game
- ready/start flow
- roll/move/buy/toll/incident/inspection
- reconnect

## Week 2

### Day 6-7
- Add GitHub Actions for staging deploy.
- Stand up a staging environment on Fly.io or AWS.
- Add the main web wrapper flow for:
- create room
- invitation link generation with referrer
- accept invitation
- start game

### Day 8-9
- Run full real-environment tests:
- auth from real wallet on Arbitrum Sepolia
- token handoff to game server
- two-player or three-player match
- reconnect and resume
- staging deploy repeatability
- validate room creation and invitation acceptance flow in browser
- validate graphical client integration path using approved offline-demo UI as the base

### Day 10
- Fix only blocker-level issues.
- Freeze scope.
- Produce final delivery notes for client handoff.

## Focus Rules

- No new mechanics.
- No speculative polish.
- No architecture detours.
- Every day must end with either a runnable stack or a shorter blocker list.

## Exit Criteria

- auth-server and game-server live in one repo
- local stack boots from documented commands
- staging deploy is automated
- core gameplay flow is tested in a real environment
- repo is understandable to a new reader in under 15 minutes
