# Evanopolis Delivery Source Of Truth

This is the only document that should track open delivery work, launch
blockers, execution order, and good-to-haves for this repo.

If another doc disagrees with this file, this file wins.

Older planning docs under `docs/migration/`, `docs/runbooks/`, and
`apps/web-wrapper/docs/` are now reference material only unless they are
explicitly linked from here as an active runbook.

## Current Snapshot

- `../tabletop-auth` remains the private auth implementation and must stay out
  of this public repo.
- `apps/rooms-api`, `apps/game-server`, and `apps/web-wrapper` all have local
  run paths, Dockerfiles, and Fly deployment workflows.
- Root `just dev` can now bootstrap the public stack against a running sibling
  auth repo.
- `apps/game-server` already hydrates matches from `rooms-api` room
  definitions on first valid join.
- `apps/web-wrapper` already performs wallet auth, room creation, invite
  lookup, payment submission and verification, and launch-payload storage.
- `/launch.html` is still only an embedded-client placeholder. There is not yet
  a real playable graphical client wired into the public wrapper.
- `apps/graphical-client/` is still a placeholder folder.
- `apps/text-client/` still depends on `../evanopolis-ui-slice` for manual
  remote testing.

## Delivery Gates

Delivery is not done until all of these are true:

- a real client launches into live gameplay from the wrapper
- game admission is enforced authoritatively, not only by wrapper-side payment
  checks
- one local path and one staging path can be rerun from documented commands
- at least one full match and reconnect path are validated in a real
  environment
- the public deploy path for `rooms-api`, `game-server`, and `web-wrapper` is
  repeatable from the checked-in workflows and runbooks

## Not Current Work

These are not delivery-week priorities unless they directly unblock the gates
above:

- visual redesign or polish beyond readability
- root `docker-compose.yml` if `just dev` and the current runbook are good
  enough
- broad cleanup of old planning docs beyond making them clearly archival
- migration of the text client unless it is the fastest way to validate real
  gameplay
- trimming non-essential support code unless it directly reduces delivery risk
- removal of baked-in demo assets unless they confuse the active path

## Active Delivery Sequence

Work in this order unless a blocker forces a change.

### 1. Replace The Launch Placeholder With A Real Playable Client

Status: launch blocker

Why this matters:

- the wrapper currently hands players into `/launch.html`, but that page still
  renders a placeholder iframe instead of the real game client
- without this, the public flow ends before actual gameplay

Done when:

- a migrated client from `../evanopolis-ui-slice/godot` is mounted through the
  wrapper-owned launch surface
- the client consumes the current launch payload (`token`, `game_id`,
  `game_server_url`, `player_address`)
- a player can enter a live match from the wrapper and reach real gameplay

### 2. Make Paid Admission Authoritative At Join Time

Status: launch blocker

Why this matters:

- the wrapper already performs payment submission and verification
- the server-side runtime does not yet show authoritative payment or admission
  enforcement in code
- wrapper-only gating is bypassable and is not enough for a real launch

Done when:

- `apps/game-server` rejects unpaid or unverified joins based on the room
  definition and the trusted auth/payment dependency
- the admission rule is documented clearly in the public repo
- automated coverage exists for allowed join, rejected join, and reconnect
  behavior

### 3. Prove The Full Local Two-Player Flow

Status: critical validation

Done when:

- the sibling auth repo boots cleanly
- the public stack boots from documented commands
- two players can authenticate, create a room, open an invite, complete
  payment, join the same match, start, and play
- reconnect is validated for at least one player
- the manual checklist lives in one obvious runbook path

### 4. Prove The Same Flow In Staging

Status: critical validation

Done when:

- the checked-in Fly workflows deploy the current public apps successfully
- smoke checks pass for `rooms-api`, `game-server`, and `web-wrapper`
- a real external end-to-end flow works for auth, invite, payment, join,
  gameplay, and reconnect
- operator-facing validation notes are captured in one obvious runbook path

### 5. Fix Only Blocker-Level Bugs Found By Steps 1-4

Status: critical stabilization

Focus here:

- auth handoff and token validity
- payment verification and admission enforcement
- match start, sync, reconnect, and authoritative state transitions
- deploy/runtime misconfiguration

Do not spend this week on:

- speculative refactors
- new gameplay mechanics
- non-essential frontend polish
- replacing working infrastructure with different infrastructure

### 6. Freeze Handoff Docs Around The Working Path

Status: final delivery prep

Done when:

- the local run path is clear
- the staging run path is clear
- the validation checklist is clear
- known limitations are called out plainly
- the repo no longer has competing backlog lists in random docs

## Per-Area Status

### `apps/auth-server`

- This repo should only document the public contract with `../tabletop-auth`.
- Private auth implementation, secrets, and operator internals remain out of
  scope here.
- Nice to have later: a cleaner operator path for obtaining a JWT for remote
  manual testing.

### `apps/rooms-api`

- Current state: room creation and public lookup are implemented, tested, and
  deployable.
- Open work: define room expiration and cleanup policy.
- Launch dependency: keep `entry_fee_amount` and room policy aligned with
  server-side admission enforcement.

### `apps/game-server`

- Current state: authoritative runtime, JWT verification, room-definition
  hydration, local run path, deploy path, and rules coverage are in place.
- Open work: authoritative payment and admission enforcement at join time.
- Defer unless needed: trimming support scripts copied from migration sources.

### `apps/web-wrapper`

- Current state: auth, room create, invite lookup, payment verification, and
  launch-payload handoff are in place.
- Open work: replace the launch placeholder with the real client and rerun full
  manual validation locally and in staging.

### `apps/graphical-client`

- Current state: placeholder only.
- Open work: this is the highest-impact missing deliverable surface in the
  repo.
- Source candidate: `../evanopolis-ui-slice/godot`.

### `apps/text-client`

- Current state: still external to this repo for remote validation.
- Use it only if it is the fastest path to prove gameplay while the graphical
  client migration is still underway.

### `deploy/` And Runbooks

- Current state: Docker plus Fly workflows exist for the public apps, and the
  local stack runbook exists.
- Open work: keep one rerunnable local path and one rerunnable staging
  validation path, then stop changing the path unless it is broken.

## Parking Lot

These stay out of the critical path unless a launch blocker forces them in:

- add a root `docker-compose.yml`
- reduce or archive old migration docs further
- document a cleaner operator JWT path for remote testing
- remove baked-in or demo-era assets once the final client path is stable
- trim migrated support code in `apps/game-server` once coverage is preserved
