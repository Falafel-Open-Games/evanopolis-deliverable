# Web Wrapper Entry Flow Plan

This document defines the intended job of `apps/web-wrapper/` before the HTML
surface is built.

The wrapper should not be treated as a throwaway staging shim. It should evolve
into the real end-user entrypoint for the online game flow.

## Product Goal

Provide the browser flow that gets a player from landing on the site to joining
the correct online match in the graphical client.

That means the wrapper owns:

- room creation
- invite-link generation and invite acceptance
- auth and wallet entry handoff
- launch handoff into the graphical client

That does not mean the wrapper owns:

- gameplay state authority
- live match status as a source of truth
- game rules or turn flow

Those remain in `apps/game-server/`.

## Source Contracts And Dependencies

The first wrapper version should be built around the contracts already present
in the repo and the private auth project:

- `apps/rooms-api/REST_API.md`
- `apps/game-server/docs/ROOMS_API_INTEGRATION.md`
- `apps/game-server/docs/RPC_API.md`
- `../tabletop-auth/docs/api.md`
- `../tabletop-auth/docs/auth-login-design.md`
- `../tabletop-auth/docs/payment-auth-overview.md`
- `../tabletop-auth/demo/token-only.html`

Operationally:

- the wrapper creates and looks up rooms through `rooms-api`
- the wrapper authenticates users through the wallet challenge flow in
  `tabletop-auth`
- the graphical client connects to `game-server` over WebSocket for gameplay
- payment verification, when required for participation, is anchored in
  `tabletop-auth`

## Auth Reality The Wrapper Must Respect

The auth project is not a generic username/password service. The current real
flow is:

1. connect an injected EVM wallet
2. ensure the wallet is on the expected chain for the current environment
3. call `POST /auth/challenge`
4. sign the SIWE message with `personal_sign`
5. call `POST /auth/verify`
6. receive a short-lived JWT

The token-only demo in `../tabletop-auth/demo/token-only.html` makes a few
important constraints explicit:

- the wrapper should treat chain enforcement as part of the entry flow
- JWTs are short-lived and intended to stay in memory, not long-term browser
  storage
- auth refresh is primarily a token-expiry concern in the normal user flow
- wallet account changes or chain changes should be treated as edge-case
  invalidation events, not as expected user actions during normal play
- the auth step should stay legible to the player instead of disappearing into
  hidden globals

For the intended product UX, this should not become a visible chain chooser.
The wrapper should target one configured chain per environment and do only what
is needed to keep the player on that chain:

- detect the current wallet network
- continue immediately if it already matches
- prompt the user to switch if it does not match
- offer network-add flow only when the configured chain is missing

For example:

- staging can be fixed to Arbitrum Sepolia
- production can be fixed to the single EVA/EverValue chain

This means the wrapper should be designed around visible auth state and clean
re-entry, not around one-time page boot assumptions.

## Payment Reality The Wrapper Must Respect

The auth demo also exposes the current pay-to-play integration path.

Today, the payment helper page can:

- derive a room-specific chain game ID from the UI UUID with
  `keccak256("evanopolis:v1:" + game_id)`
- call `approve` on the EVA token when allowance is too low
- call `play(amount, potentialReferrer, gameIdBytes32)` on the payment adapter
- call `POST /payments/verify` with `txHash`, `gameId`, and `amount`

That implies a likely wrapper responsibility boundary:

- the wrapper may eventually need to present payment readiness or payment
  confirmation as part of room entry
- payment proof should not be treated as a separate unrelated subsystem; it is
  tied to the same `game_id` the wrapper creates and shares
- referrer information in invite URLs may matter to the payment path, since the
  current demo supports `potential_referrer`

For the first wrapper pass, the priority is still room creation, invite, auth,
payment, and launch. Payment is not an optional side path in the intended
product flow, so the wrapper should treat it as a first-class entry step.

## Intended End-User Flow

### 1. Landing

The player lands on the wrapper and can clearly choose one of two paths:

- create a room
- join a room from an invite

This needs to feel like the real product entrypoint, not a debug screen.

### 2. Auth

Before creating a room or joining one, the wrapper must establish player
identity through the auth flow trusted by the deployed game server.

The wrapper should:

- make wallet connection and the expected network explicit
- surface auth errors clearly
- keep JWT handling in memory
- support re-auth when the token expires
- invalidate or recover cleanly if the wallet account or network changes
  underneath the page

### 3. Room Creation

For the creator flow, the wrapper should:

- collect the minimal room settings needed for `POST /v0/rooms`
- call `rooms-api`
- receive a `game_id`
- show a shareable invite link carrying that `game_id`
- preserve any creator/referrer data the later payment flow may need

The first staged version should stay narrow and only expose fields the backend
already supports safely.

### 4. Invite Acceptance

For an invited player, the wrapper should:

- read `game_id` from the invite URL
- validate that the room exists through `GET /v0/rooms/:game_id`
- make the room they are joining explicit before launch
- keep any invite-carried referrer hint available if the payment flow later
  needs it

Players should not have to infer whether they are creating a room, joining a
room, or reconnecting.

Invite links should be the primary join path.

Manual `game_id` entry should still exist as a fallback for cases where:

- the invite URL is broken or stripped by another app
- the player only received a room code
- the player needs a recovery path after context was lost between devices,
  browsers, or sessions

### 5. Payment Gate Placeholder

The wrapper should include a clear payment step before launch.

That step should support:

- allowance check
- `approve` when needed
- `play` transaction submission
- `txHash` capture and persistence
- `/payments/verify` confirmation tied to the same `game_id`

This should not be treated as a separate unrelated subsystem. Payment belongs
inside the same room-entry flow as auth and invite handling.

### 6. Launch Into Client

When the player is ready, the wrapper hands the correct launch parameters to the
graphical client:

- authenticated player token
- target `game_id`
- target game-server endpoint

The wrapper should not try to reimplement gameplay. Its job is to hand the
player cleanly into the real client runtime.

## First Staged Deliverable

The first wrapper milestone should prove this end-to-end path:

1. connect wallet and authenticate in browser
2. create a room from the wrapper
3. copy or open an invite link
4. accept the invite in the wrapper
5. complete the payment step for the room
6. hand both players into the correct online match flow

## Non-Goals For The First Wrapper Pass

- no matchmaking
- no public room directory
- no live match administration panel
- no speculative lobby complexity beyond what the current server flow needs
- no visual redesign detached from the approved final client direction
- no debug-form-first UI copied directly from `token-only.html`

The auth demo is useful as an integration reference. It is not the wrapper
product model.

## Open Product Questions

These should be answered before the HTML flow hardens:

- what exact auth and wallet step should the wrapper present to a first-time
  user?
- should invite links land directly in a join page, or in a landing page with
  join intent preselected?
- how should wrong-network state be presented without exposing unnecessary chain
  choice?
- when should payment happen relative to room join and game launch?
- how visible should `potential_referrer` be in the end-user flow?
- what launch mechanism should the wrapper use for the graphical client in web,
  desktop, or both?
- what room details are worth showing before launch without implying fake live
  status?
- how should reconnect or re-entry appear in the wrapper if a player already
  has a valid token and game link?

## Implementation Direction

Keep the first implementation explicit and testable:

- favor a small number of pages or routes with obvious responsibilities
- keep API boundaries visible in the code
- avoid burying room, auth, payment, and launch flow in abstraction layers
- make manual staging verification easy

The wrapper should feel close to the intended final product, but the first pass
still needs to optimize for correctness and end-to-end validation.
