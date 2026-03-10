# Web Wrapper

This app is the browser shell around the game.

## Purpose

It should provide the main HTML flow for:

- creating a new game room
- generating an invitation link with the creator as referrer
- accepting an invitation
- starting the game client

## Likely Responsibilities

- wallet/auth entry flow handoff
- room/lobby entry pages
- launch parameter handoff into the graphical client
- simple, readable pages that are easy to test in staging

## Scope Note

This is distinct from the graphical client itself.

The wrapper owns the surrounding browser product flow; the graphical client owns the actual in-game experience.
