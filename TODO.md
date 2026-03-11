# Evanopolis Deliverable TODO

## Current Priority: Game Server Staging and CI/CD

- Verify the existing Fly.io staging deploy path for `apps/game-server/` is fully documented and reproducible from a clean machine.
- Review `.github/workflows/game-server-image.yml` and decide whether staging should deploy directly from GitHub Actions or remain a manual `fly deploy` step for now.
- If staging deploy from GitHub Actions is desired, add the required GitHub secrets and variables, then create a dedicated deploy workflow for the Fly app.
- Document the exact GitHub secrets, Fly app name, and operational steps needed to keep the staging game server in sync with `main`.
- Re-test the published image pull path from GHCR and Docker Hub after the deploy workflow is finalized.

## Next Major Task: Replace Baked-In Demo Matches

- Design the server-side flow for creating a new game room at runtime instead of relying on baked-in `configs/*.toml`.
- Define how a room creator gets a shareable `game_id` and how invited players use it to join the same room.
- Decide where room metadata lives and how long unused rooms persist.
- Clarify the boundary between `apps/web-wrapper/` room creation UX and `apps/game-server/` room lifecycle/auth enforcement.
- Remove or isolate baked-in demo configs from the production/staging path once runtime room creation exists.

## Follow-Up Validation

- Test text-only clients from `../evanopolis-ui-slice` against the Fly game server over `wss://`.
- Add a short runbook for obtaining a JWT from the deployed auth service and joining a remote game-server room.
- Keep the deliverable docs aligned with the real deploy and testing path as it evolves.
