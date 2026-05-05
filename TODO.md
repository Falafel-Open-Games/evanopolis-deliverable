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
- `/launch.html` now hands the saved launch payload into the real graphical
  client over the wrapper-owned iframe bridge.
- `apps/graphical-client/` is now a real Godot client with waiting room,
  gameplay board, action UI, energy allocation, reconnect-aware session state,
  and a documented devlog trail through `011`.

## Delivery Gates

Delivery is not done until all of these are true:

- a real client launches into live gameplay from the wrapper in both local and
  staging validation paths
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
- trimming non-essential support code unless it directly reduces delivery risk
- removal of baked-in demo assets unless they confuse the active path

## Active Delivery Sequence

Work in this order unless a blocker forces a change.

### 1. Enforce Admission Authoritatively At Join Time

Status: launch blocker

Why this matters:

- the wrapper already performs payment submission and verification
- the public browser path is not enough by itself; the server must reject joins
  that do not satisfy the trusted admission rule
- this remains the main missing launch-grade protection in the public stack

Done when:

- `apps/game-server` rejects unpaid or unverified joins based on the room
  definition and the trusted auth/payment dependency
- the admission rule is documented clearly in the public repo
- automated coverage exists for allowed join, rejected join, and reconnect
  behavior

### 2. Prove The Full Local Two-Player Browser Flow

Status: critical validation

Done when:

- the sibling auth repo boots cleanly
- the public stack boots from documented commands
- two players can authenticate, create a room, open an invite, complete
  payment, join the same match, start, launch the graphical client, and play
- reconnect is validated for at least one player
- the manual checklist lives in one obvious runbook path

### 3. Prove The Same Flow In Staging

Status: critical validation

Done when:

- the checked-in Fly workflows deploy the current public apps successfully
- smoke checks pass for `rooms-api`, `game-server`, and `web-wrapper`
- a real external end-to-end flow works for auth, invite, payment, join,
  gameplay, and reconnect
- operator-facing validation notes are captured in one obvious runbook path

### 4. Close The Highest-Value Graphical Client Readability Gaps

Status: important but not launch-blocking unless they hide authoritative state

Focus here:

- center-board dice presentation from `rpc_dice_rolled(...)`
- gameplay feedback that keeps turn results readable without relying on logs
- only the narrowest polish needed to make real matches understandable during
  validation

Do not turn this into:

- a broad visual redesign
- speculative camera or animation work disconnected from match readability
- client-side rule simulation

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
  launch-payload handoff into the embedded graphical client are in place.
- Open work: rerun the full manual browser flow locally and in staging against
  the real exported client, then document the working path.

### `apps/graphical-client`

- Current state: active gameplay client with waiting room, board integration,
  action controls, energy allocation, reconnect-aware session state, and a web
  export path used by the wrapper.
- Open work: finish the highest-value gameplay readability slices and validate
  the real browser launch/reconnect flow repeatedly.
- Immediate next slice: center-board dice presentation, tracked in
  `apps/graphical-client/docs/devlog/011.md`.

### `deploy/` And Runbooks

- Current state: Docker plus Fly workflows exist for the public apps, and the
  local stack runbook exists.
- Open work: keep one rerunnable local path and one rerunnable staging
  validation path, then stop changing the path unless it is broken.

## Parking Lot

These stay out of the critical path unless a launch blocker forces them in:

- add a root `docker-compose.yml`
- reduce or archive old migration docs further
- update stale app READMEs and planning docs that still describe the graphical
  client and `/launch.html` as placeholders
- document a cleaner operator JWT path for remote testing
- remove baked-in or demo-era assets once the final client path is stable
- trim migrated support code in `apps/game-server` once coverage is preserved

## Future Devlog Candidates

These are likely future slices, but they should not enter the active delivery
sequence until they are promoted into a concrete devlog or become validation
blockers.

- music and sound
- camera movement and framing polish
- win / lose screens
- add an open source license
- add a credits page
- polish the waiting room
- polish gameplay event feedback
- make the landing page and room creation pages visually strong
