# Web Wrapper Wireframes

These are low-fidelity layout sketches for discussion only.

They are here to help review screen structure, not to define visual style.

## Landing

```text
+---------------------------------------------------------------+
| Evanopolis                                                    |
| Play online with your wallet and invite link                  |
|                                                               |
| [ Create a Room ]     [ Join with Invite ]                    |
|                                                               |
| If you already have an invite, open it here.                  |
| [ paste game link or game_id __________________________ ]      |
| [ Continue ]                                                  |
|                                                               |
| Have only a room code? Use manual join.                       |
| [ Enter game code instead ]                                   |
|                                                               |
| Small print: requires browser wallet on the supported network |
+---------------------------------------------------------------+
```

## Auth

```text
+---------------------------------------------------------------+
| Connect Wallet                                                |
| You are continuing to: Join room 550e8400...                  |
|                                                               |
| Network required: Arbitrum Sepolia                            |
| Wallet: Not connected                                         |
|                                                               |
| [ Connect Wallet ]                                            |
|                                                               |
| After connection:                                             |
| - switch network if needed                                    |
| - sign one message to continue                                |
|                                                               |
| Error area                                                    |
+---------------------------------------------------------------+
```

## Create Room

```text
+---------------------------------------------------------------+
| Create Room                                                   |
|                                                               |
| Players                                                       |
| ( ) 2 players                                                 |
| ( ) 3 players                                                 |
| ( ) 4 players                                                 |
|                                                               |
| [ Create Room ]                                               |
|                                                               |
| Creates a shareable game room and invite link.                |
+---------------------------------------------------------------+
```

## Invite Ready

```text
+---------------------------------------------------------------+
| Room Created                                                  |
|                                                               |
| Game ID                                                       |
| 550e8400-e29b-41d4-a716-446655440000                          |
|                                                               |
| Invite link                                                   |
| [ https://.../room/550e8400...?ref=..._______________ ]       |
| [ Copy Link ]   [ Preview Join Flow ]                         |
|                                                               |
| Waiting for your invited player?                              |
| You can continue when ready.                                  |
|                                                               |
| [ Continue to Game Entry ]                                    |
+---------------------------------------------------------------+
```

## Join Confirmation

```text
+---------------------------------------------------------------+
| Join Room                                                     |
|                                                               |
| You are about to join room                                    |
| 550e8400-e29b-41d4-a716-446655440000                          |
|                                                               |
| Room type: 2-player game                                      |
|                                                               |
| [ Continue ]   [ Back ]                                       |
|                                                               |
| Small print: you will enter the online game client next       |
+---------------------------------------------------------------+
```

## Payment Placeholder

```text
+---------------------------------------------------------------+
| Entry Payment                                                 |
|                                                               |
| Room: 550e8400-e29b-41d4-a716-446655440000                    |
| Network: Arbitrum Sepolia                                     |
| Token: EVA / TRT                                              |
| Amount: 1.0                                                   |
|                                                               |
| Step 1: approve token if needed                               |
| [ Approve ]                                                   |
|                                                               |
| Step 2: complete required entry payment                       |
| [ Pay and Continue ]                                          |
|                                                               |
| Verification status area                                      |
| You will enter the game after payment is verified.            |
+---------------------------------------------------------------+
```

## Launch Handoff

```text
+---------------------------------------------------------------+
| Ready to Enter Game                                           |
|                                                               |
| Authenticated as 0x1234...abcd                                |
| Room: 550e8400-e29b-41d4-a716-446655440000                    |
| Server: wss://...                                             |
|                                                               |
| [ Launch Game ]                                               |
|                                                               |
| If launch fails, keep this page open and try again.           |
+---------------------------------------------------------------+
```
