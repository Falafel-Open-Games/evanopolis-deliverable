# Evanopolis Deliverable TODO

## Current Priority: Game Server Staging and CI/CD

- Completed: document the Fly.io staging deploy path and the GitHub-managed Fly runtime configuration workflow.
- Completed: review `.github/workflows/game-server-image.yml` vs Fly deploy and keep them as separate workflows; Fly staging deploys from source with `flyctl deploy --remote-only`.
- Completed: add the required GitHub secrets and variables, and create a dedicated Fly deploy workflow for the game server.
- Completed: document the exact GitHub secret, variables, and operational steps needed to keep the staging game server in sync with `main`.
- Re-test the published image pull path from GHCR and Docker Hub after the deploy workflow is finalized.
- Run one clean-machine validation pass after a fresh push to confirm both GitHub Actions workflows succeed and the Fly endpoint remains healthy.

## Next Major Task: Replace Baked-In Demo Matches

- Design the server-side flow for creating a new game room at runtime instead of relying on baked-in `configs/*.toml`.
- Define how a room creator gets a shareable `game_id` and how invited players use it to join the same room.
- Decide where room metadata lives and how long unused rooms persist.
- Clarify the boundary between `apps/web-wrapper/` room creation UX and `apps/game-server/` room lifecycle/auth enforcement.
- Remove or isolate baked-in demo configs from the production/staging path once runtime room creation exists.

## Follow-Up Validation

- Completed: test text-only clients from `../evanopolis-ui-slice` against the Fly game server over `wss://`.
- Add a short runbook for obtaining a JWT from the deployed auth service and joining a remote game-server room.
- Keep the deliverable docs aligned with the real deploy and testing path as it evolves.
