# Evanopolis Deliverable - Agent Notes

This file is the Codex-facing source of truth for workflow and engineering
constraints in this monorepo.

Its job is to keep the consolidated repo readable, predictable, and focused on
shipping the final deliverable.

## Mission

- Consolidate the canonical deliverable pieces into one repo.
- Prioritize server readiness, deployment, and real-environment testing.
- Avoid scope growth unless it directly reduces delivery risk.

## Monorepo Priorities

Work in this order unless a blocker forces a change:

1. `apps/game-server/`
2. `deploy/`
3. `.github/workflows/`
4. `apps/web-wrapper/`
5. `apps/graphical-client/`
6. `apps/text-client/` only as a support/testing tool
7. `apps/auth-server/` only as a public integration stub for the private auth repo

## Workflow Notes

- For PR workflow and version control guidance, use `jj` (not git).
- Always track PR bookmarks with origin using `jj bookmark track <branch-name>@origin`.
- Push is the final step and is done by the user (keyed); do not run `jj git push` yourself.
- When cutting a PR, pick a branch name yourself and track the bookmark with origin without asking.
- Commit messages must use a one-line Conventional Commit summary, then a blank line, then a fuller descriptive summary.
- Use `jj describe` to finalize PR changes instead of `jj commit` to avoid creating a new empty revision.
- When writing multi-line messages with `jj describe -m`, use a literal blank line inside the quoted string. Do not type `\n` or `\\n`.
- If a repo or app has a build-id sync step equivalent to `just sync-build-id`, run it before opening a PR.

Example:
`jj describe -m "feat: summary

Body line one.
Body line two."`

## Delivery Discipline

- Prefer migration and consolidation over invention.
- Prefer deleting stale or duplicate material over preserving confusing history.
- Prefer one obvious run path over multiple partial run paths.
- No new gameplay mechanics unless explicitly requested.
- Late in delivery, optimize for deployability, testability, and human readability.

## Bug-Fix Rule

- When addressing a bug, prefer writing a failing test first, then implement the fix.
- If the bug lives in a system without practical automated coverage yet, document the manual repro and validation steps clearly.

## Monorepo Structure

- `apps/auth-server/` is a public documentation and integration stub for the private auth service repo.
- `apps/game-server/` is the Godot headless multiplayer server and authoritative rules runtime.
- `apps/web-wrapper/` is the browser shell for room creation, invite links, referral flow, invitation acceptance, and launch into the game.
- `apps/graphical-client/` is the final player-facing game client.
- `apps/text-client/` is a debugging and testing client, not the main deliverable surface.
- `deploy/` contains Docker, Compose, staging, and cloud deployment assets.
- `docs/` contains migration notes, runbooks, architecture, and delivery plans.
- `tests/` is for cross-app integration and environment verification assets.

## App-Specific Guidance

### `apps/auth-server`

- Do not migrate private auth implementation code into this public repository.
- Keep the folder limited to integration docs, local wiring notes, and explicit contracts with the private repo.
- Never copy secrets, JWTs, signatures, private deploy details, or sensitive operational notes into this repo.
- When auth integration changes, update the public contract here and the implementation in `../tabletop-auth`.

### `apps/game-server`

- Keep the server authoritative.
- Preserve deterministic ordering and reconnect safety.
- Keep tests focused on rules, session flow, auth handoff, and real server behavior.
- Do not treat the text client as part of the core runtime architecture.

### `apps/web-wrapper`

- Keep pages simple, explicit, and easy to test manually.
- Optimize for room creation, invitation handling, and launch handoff clarity.
- Avoid burying core flow inside frontend abstraction layers unless the codebase already requires them.

### `apps/graphical-client`

- The final graphical client should reuse the approved UI from the offline demo where possible.
- This is an adaptation effort, not a redesign from scratch.
- Replace offline/local game logic with multiplayer RPC-driven flow.
- Keep the server as the source of truth for state transitions.

## GDScript Preferences

Apply these in Godot code unless a local file or subsystem already has a stronger established pattern:

- Avoid type inference syntax like `:=`.
- Use explicit types to prevent Variant inference warnings.
- Prefer fail-fast checks for required nodes; avoid silent `null` guards.
- Use asserts and fail-fast behavior instead of defensive early returns when invariants are under our control.
- Use direct autoload access when the dependency is required.
- Avoid redundant clamps when UI options are controlled and aligned with code enums.
- Avoid variable names that shadow Node properties such as `name`, `owner`, or `hash`.
- Use 4-space indentation.
- Prefer `snake_case` for variables and functions and `PascalCase` via `class_name` for Godot classes.

## TypeScript / Web Preferences

- Use the formatter already established by the app, typically Prettier.
- Favor explicit module boundaries and explicit exports.
- Avoid hidden globals, especially around auth state, crypto, and environment configuration.
- Keep browser flows readable before making them clever.

## Testing Expectations

- Prefer fast, local, deterministic tests by default.
- Keep auth-related tests in this public repo focused on integration contracts and token handoff expectations.
- Keep game-server tests focused on match flow, incidents, inspection, reconnect, sync, and auth integration points.
- For deploy/integration work, add a clear manual verification checklist when full automation is not yet realistic.

## Build Numbering

- If the graphical client or other deliverable surface exposes a build id, keep it synchronized before PRs and releases.
- Do not handwave build numbering; either automate it or document the exact update step in the app README or root runbook.

## Documentation Standard

Every app folder should make these clear:

1. What it is for.
2. How to run it locally.
3. How to test it.
4. What remains to be migrated or hardened.

If that is not obvious, improve the docs before adding more complexity.

## PR Content Guidelines

- State scope clearly.
- Include the commands run for tests/build/validation.
- Link related issue docs or migration docs when relevant.
- Call out deploy-impacting or security-impacting changes explicitly.
- For user-facing flows, include concrete manual test notes.

## Related Source Repos

Current migration sources:

- `../tabletop-auth`
- `../evanopolis-ui-slice`

When migrating from those repos, preserve useful constraints but do not copy stale scope assumptions blindly.
`tabletop-auth` remains private and external unless the client requirement changes.
