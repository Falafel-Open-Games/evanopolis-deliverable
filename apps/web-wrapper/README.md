# Web Wrapper

This app is the browser shell around the game.

## Purpose

It is intended to become the real end-user entrypoint for:

- creating a new game room
- generating an invitation link with the creator as referrer
- accepting an invitation
- completing auth and, later, payment gating as needed
- launching the graphical client into the correct online match

## Status

The wrapper now has a minimal `Vite + React + TypeScript` runtime.

The current implementation is intentionally a live wireframe:

- neutral visual styling
- product-facing first-page structure for auth, room creation, invite recovery,
  payment, and launch
- code-level runtime defaults while the real integrations are added

The roadmap for this phase lives in
[docs/LIVE_WIREFRAME_ROADMAP.md](./docs/LIVE_WIREFRAME_ROADMAP.md).

## Responsibilities

- wallet/auth entry flow handoff
- room/lobby entry pages
- invite acceptance
- possible payment-step integration with the private auth/payment stack
- launch parameter handoff into the graphical client
- simple, readable pages that are easy to test in staging

## Contracts And Planning

Start with the wrapper plan in
[docs/ENTRY_FLOW_PLAN.md](./docs/ENTRY_FLOW_PLAN.md).

That plan is intentionally tied to the current backend contracts in:

- `apps/rooms-api/REST_API.md`
- `apps/game-server/docs/ROOMS_API_INTEGRATION.md`
- `apps/game-server/docs/RPC_API.md`
- `../tabletop-auth`

## Local Run

Work from this directory:

```bash
cd apps/web-wrapper
```

Install dependencies once:

```bash
npm install
```

Run the local dev server:

```bash
npm run dev
```

To point the wrapper at a non-default environment, use Vite env vars. For
local overrides, create `.env.local` in this folder. The default local values
already match the repo-level runbook, so `.env.local` is only needed when you
want to override them.

The wrapper currently reads these Vite env vars:

- `VITE_AUTH_BASE_URL`
- `VITE_ROOMS_BASE_URL`
- `VITE_EXPECTED_CHAIN_ID`
- `VITE_GAME_SERVER_URL`
- `VITE_GRAPHICAL_CLIENT_URL`
- `VITE_PAYMENT_TOKEN_ADDRESS`
- `VITE_PAYMENT_HANDLER_ADDRESS`
- `VITE_PAYMENT_ADAPTER_ADDRESS`
- `VITE_DEV_SKIP_PAYMENT`

`VITE_DEV_SKIP_PAYMENT=true` is a development-only quality-of-life flag that
lets the wrapper show `Launch Game` without payment verification while keeping
the payment actions available for demo and integration testing. It should not
be enabled in staging or production.

For the current repo-level local path, see
[docs/runbooks/local-stack.md](../../docs/runbooks/local-stack.md).

Build the static app:

```bash
npm run build
```

## Container Runtime Config

The checked-in wrapper Docker image is intended to stay reusable across
environments.

When served from the container path under `deploy/docker/web-wrapper/`, runtime
configuration is injected into `/runtime-config.js` at container startup from:

- `AUTH_BASE_URL`
- `ROOMS_BASE_URL`
- `EXPECTED_CHAIN_ID`
- `GAME_SERVER_URL`
- `GRAPHICAL_CLIENT_URL`
- `PAYMENT_TOKEN_ADDRESS`
- `PAYMENT_HANDLER_ADDRESS`
- `PAYMENT_ADAPTER_ADDRESS`

That means Fly.io and other container deploys do not need a staging-specific
wrapper rebuild just to change service URLs or payment contract addresses.

## Testing Direction

The first useful validation target for this app is not pixel polish. It is a
real browser flow that can:

- authenticate with the deployed auth service
- create a room through `rooms-api`
- open or share an invite link carrying `game_id`
- complete the payment step through the live payment contracts
- hand the player into the real online game flow

The wrapper now has real auth, room creation, invite lookup, payment, and a
provisional launch handoff.

Current invite links also carry `potential_referrer` when the creator wallet is
known, so invite-first joins can use the creator wallet as the payment referral
hint.

The launch handoff is still provisional:

- the wrapper builds a launch payload containing `token`, `game_id`,
  `game_server_url`, and `player_address`
- after payment verification, the wrapper stores that payload in session state
  and opens its own internal `/launch.html` route
- `/launch.html` embeds the configured graphical client URL, then hands the
  launch payload to the iframe over the `open-game-host` `postMessage`
  protocol once the child sends `client_ready`

## Staging Deploy

The checked-in staging path for this app is now:

- Docker image: `deploy/docker/web-wrapper/Dockerfile`
- Fly app config: `deploy/fly/web-wrapper/fly.toml`
- GitHub image workflow: `.github/workflows/web-wrapper-image.yml`
- GitHub Fly deploy workflow: `.github/workflows/web-wrapper-fly-deploy.yml`

## Remaining Work

Active delivery tracking now lives in the repo root
[TODO.md](../../TODO.md).

For this app, the main live launch blocker is replacing the current
`/launch.html` placeholder with the real client and rerunning the full local
and staging browser validation path.

## Scope Note

This is distinct from the graphical client itself.

The wrapper owns the surrounding browser product flow; the graphical client
owns the actual in-game experience.
