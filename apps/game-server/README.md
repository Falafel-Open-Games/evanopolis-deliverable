# Game Server

Canonical source to migrate from: `../evanopolis-ui-slice/godot2`

## Purpose

This app will become the final home for:

- Godot headless multiplayer server
- rules engine and authoritative match state
- server-side tests

## First Migration Slice

- move headless server runtime
- keep tests for match flow, incidents, inspection, reconnect, and auth integration points
- exclude the text-only client from the core server migration

## Explicit v0 Focus

- stable match hosting
- auth handshake compatibility
- reconnect safety
- real-environment validation

## Definition of Done For Migration

- server runs from this repo
- tests can run from this repo
- local compose can boot auth + game together
- server docs are understandable without opening the old repo
