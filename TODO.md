# Evanopolis Deliverable Backlog

This file is for real backlog work that is not the current session focus.

Immediate focus should stay in active session notes and the work itself, not
here.

## Backlog

- add one documented local integration path for the public apps with the private
  `../tabletop-auth` checkout
- tighten app-level docs where the required run/test/hardening status is still
  not explicit, especially in `apps/web-wrapper/` and `apps/graphical-client/`
- trim or isolate non-essential support code in `apps/game-server/` once that
  can be done without weakening current coverage
- define the `rooms-api` room-lifecycle policy for expiration and cleanup,
  including unused rooms and rooms whose matches have already finished
- decide whether the repo still needs `docs/migration/` planning artifacts in
  their current form or whether they should be reduced to durable runbooks only
- keep the staging validation path re-runnable after deploy/config changes,
  including the remote text-client flow

## Parking Lot

- document a cleaner operator path for obtaining a JWT from the deployed auth
  service for manual remote testing
- decide whether a root local stack runner such as `docker-compose.yml` or an
  equivalent documented command path is still worth adding
- review whether any remaining baked-in/demo-era assets should be removed from
  the public deliverable repo once the final client path is stable
