# Text Client

This folder is reserved for the debugging and testing text client.

The remote-capable text client used for manual Fly testing is not yet migrated
into this monorepo. The current working client lives in the sibling repository
at `../evanopolis-ui-slice`.

## Purpose

Use the text client as a manual verification tool for the deployed game server.
It is not a core deliverable surface.

## Remote Fly Match Test

Use these steps to manually test a match between two text clients against the
deployed Fly servers.

### Prerequisites

- A deployed game server endpoint, for example
  `wss://<your-game-server>.fly.dev`
- A deployed rooms API endpoint, for example
  `https://<your-rooms-api>.fly.dev`
- Two valid JWTs for two different users from the same auth service trusted by
  the deployed game server
- The sibling repo `../evanopolis-ui-slice` checked out locally

### 1. Create a room

Create a two-player room through the deployed rooms API, then export the
returned `game_id` as `GAME_ID`.

```bash
export ROOMS_URL=https://<your-rooms-api>.fly.dev
export JWT_A=<token-for-player-a>

curl -sS \
  -X POST "$ROOMS_URL/v0/rooms" \
  -H "authorization: Bearer $JWT_A" \
  -H "content-type: application/json" \
  -d '{"player_count":2}'

export GAME_ID=<game_id-from-response>
```

### 2. Start player A

In the first terminal:

```bash
cd ../evanopolis-ui-slice
just text-only-client --url wss://<your-game-server>.fly.dev --game-id "$GAME_ID" --auth-token "$JWT_A"
```

### 3. Start player B

In the second terminal:

```bash
cd ../evanopolis-ui-slice
export JWT_B=<token-for-player-b>
just text-only-client --url wss://<your-game-server>.fly.dev --game-id "$GAME_ID" --auth-token "$JWT_B"
```

### 4. Play the match

Expected flow:

- Both clients authenticate successfully
- Both clients join the same `game_id`
- The match starts once both players are present

The text client reads from stdin:

- Press `Enter` when prompted to roll
- Enter `y` or `n` when prompted for buy or other decisions
- Verify actions from one client are reflected in the other client terminal

### 5. Validate server behavior

Confirm these manual checks:

- Both clients connect over `wss://`
- Both clients receive consistent game state updates
- Turn order remains synchronized across terminals
- The server remains authoritative for state transitions

## Status

This folder remains a placeholder until the text client is migrated into this
repo. Until then, use the sibling repo path above for manual remote testing.
