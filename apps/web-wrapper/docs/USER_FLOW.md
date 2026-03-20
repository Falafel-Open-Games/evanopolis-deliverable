# Web Wrapper User Flow

This document captures the intended user-flow structure for the wrapper before
UI implementation begins.

Use this alongside:

- `ENTRY_FLOW_PLAN.md`
- `SCREEN_SPECS.md`
- `WIREFRAMES.md`

## Route-Level Shape

This is a likely first route structure, not a final implementation contract.

```mermaid
flowchart LR
    A["/"] --> B["/create"]
    A --> C["/join"]
    A --> D["/room/:game_id"]

    B --> E["/room/:game_id/invite"]
    C --> F["/room/:game_id/join"]
    D --> F

    E --> G["/room/:game_id/launch"]
    F --> G
```

## Create Room Flow

```mermaid
flowchart TD
    A[Landing or create route] --> B{Authenticated?}
    B -->|No| C[Wallet sign-in]
    B -->|Yes| D[Room setup form]
    C --> D
    D --> E[POST /v0/rooms]
    E --> F[Receive game_id]
    F --> G[Show invite link]
    G --> H[Creator can continue to launch]
```

## Join Invite Flow

```mermaid
flowchart TD
    A[Invite link with game_id] --> B[Read URL params]
    B --> C[GET /v0/rooms/:game_id]
    C --> D{Room exists?}
    D -->|No| E[Invalid or unavailable room screen]
    D -->|Yes| F{Authenticated?}
    F -->|No| G[Wallet sign-in]
    F -->|Yes| H[Join confirmation]
    G --> H
    H --> I[Payment step]
    I --> J[Launch handoff]
```

## Manual Join Fallback

This is a recovery path, not the preferred product entry.

```mermaid
flowchart TD
    A[Landing] --> B[User selects manual join fallback]
    B --> C[Enter game_id]
    C --> D[GET /v0/rooms/:game_id]
    D --> E{Room exists?}
    E -->|No| F[Invalid or unavailable room screen]
    E -->|Yes| G[Continue through the normal join flow]
```

## Auth State Handling

```mermaid
flowchart TD
    A[User enters wrapper flow] --> B{JWT present and usable?}
    B -->|Yes| C[Continue]
    B -->|No| D[Connect wallet]
    D --> E[Check expected chain]
    E --> F[Challenge]
    F --> G[Sign SIWE message]
    G --> H[Verify]
    H --> I[Store JWT in memory]
    I --> C

    C --> J{Token expired?}
    J -->|Yes| D
    J -->|No| K[Stay in flow]

    K --> L{Wallet account or chain changed?}
    L -->|Yes| M[Invalidate session state and recover cleanly]
    L -->|No| N[Proceed normally]
```

## Payment Placement

Payment is part of the required entry flow.

```mermaid
flowchart TD
    A[Room ready to join or launch] --> B[Check allowance]
    B --> C{Allowance sufficient?}
    C -->|No| D[Approve token]
    C -->|Yes| E[Submit play tx]
    D --> E
    E --> F[Capture txHash]
    F --> G[POST /payments/verify]
    G --> H{Verified?}
    H -->|No| I[Payment error/retry]
    H -->|Yes| J[Launch]
```

## Review Notes

The purpose of these diagrams is to settle:

- where each decision point belongs
- which steps are required versus optional
- which steps deserve their own screen
- where auth and payment are allowed to interrupt the happy path

Auth in these diagrams should be read as a flow gate or screen state, not as a
requirement for a dedicated `/auth` route.

Invite-link join should be treated as the primary path. Manual room-code entry
is a fallback for recovery and edge cases.

The purpose is not to lock the visual design yet.
