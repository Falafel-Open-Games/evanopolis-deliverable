# Auth Server

Canonical source to migrate from: `../tabletop-auth`

## Purpose

This app will become the final home for:

- wallet challenge and signature verification
- JWT/session issuance
- Arbitrum Sepolia auth and pay-to-play contract integration
- auth-related deployment assets

## First Migration Slice

- copy current auth API and its docs
- keep current Dockerfile and Fly/AWS deploy assets
- keep tests that validate auth, nonce, JWT, and protected routes

## Out of Scope For The First Slice

- frontend/demo cleanup
- major auth redesign
- contract feature expansion

## Definition of Done For Migration

- app runs from inside this monorepo
- local env docs are clear
- existing auth tests still pass
- staging deploy path is documented
