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

There is no implementation in this folder yet beyond documentation.

The current work here is to define the entry flow carefully enough that the
first HTML implementation already points toward the final product instead of
becoming a throwaway staging shell.

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

No app runtime exists here yet.

When implementation starts, this README should be updated with one documented
local run path and one documented staging validation path.

## Testing Direction

The first useful validation target for this app is not pixel polish. It is a
real browser flow that can:

- authenticate with the deployed auth service
- create a room through `rooms-api`
- open or share an invite link carrying `game_id`
- hand the player into the real online game flow

## Scope Note

This is distinct from the graphical client itself.

The wrapper owns the surrounding browser product flow; the graphical client owns the actual in-game experience.
