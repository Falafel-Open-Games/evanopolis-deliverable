# Auth Server

This directory is intentionally a public stub.

The canonical auth service implementation remains private in:
`../tabletop-auth`

## Purpose

This folder exists to document:

- the public-facing integration contract with the private auth service
- how local development in this repo should point at `../tabletop-auth`
- what deployment surfaces depend on the auth service
- what must not be copied into this public repository

## Private Repo Responsibilities

- wallet challenge and signature verification
- JWT/session issuance
- Arbitrum Sepolia auth and pay-to-play contract integration
- auth-related deployment assets
- auth implementation tests and security-sensitive operational details

## Public Repo Responsibilities

- document the auth API surface expected by the game server and web wrapper
- document local wiring for running this repo against a sibling `../tabletop-auth` checkout
- document staging/prod integration points
- keep only non-sensitive examples and placeholders here

## Local Development Assumption

Clone the private auth repo beside this one:

- `../evanopolis-deliverable`
- `../tabletop-auth`

Then point local Compose/scripts at the sibling `../tabletop-auth` checkout.

## Out of Scope

- copying private auth implementation into this repo
- duplicating auth deployment secrets or operator notes
- treating this folder as a runnable app
