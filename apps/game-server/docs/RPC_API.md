# Game Server RPC API

This document is the canonical RPC contract for the migrated Godot game-server.

The shared RPC surface is implemented in `scripts/headless_rpc.gd`. Server-side
handling lives in `scripts/server_main.gd`. The text client implementation in
`scripts/client_main.gd` is useful as a behavioral reference for reconnect,
sync, and prompt flow, but it is not the source of truth.

## Transport

- Godot high-level multiplayer RPC over `WebSocketMultiplayerPeer`
- shared RPC node contract via `scripts/headless_rpc.gd`
- one headless server process can host multiple matches
- clients connect, authenticate, join a `game_id`, then consume broadcast events

## Delivery Rules

- Broadcast gameplay events use a monotonic per-match `seq`
- Client-specific responses use `seq = 0`
- Reconnect uses `rpc_sync_request(game_id, player_id, last_applied_seq)`
- Server responds to reconnect with `rpc_state_snapshot(0, snapshot)` then `rpc_sync_complete(0, final_seq)`
- During sync, clients must queue live broadcast events and apply them only after the snapshot is installed

## Economy V0 Contract

The server is authoritative for all economy values. Clients should consume
property economy data from `rpc_board_state`, `rpc_tile_landed`, and
`rpc_state_snapshot`; clients should not duplicate these numbers locally.

Global economy values:

- Starting fiat: `130.0`
- Bitcoin goal: `20.0`
- Toll: `buy_price * 0.10`
- Tile types: `A`, `B`, `C`

Each property tile carries these economy fields:

- `tile_index: int`
- `city: String`
- `tile_type: String` - one of `A`, `B`, `C`
- `buy_price: float`
- `energy_production: int`
- `toll: float`
- `sell_100_fiat: float`
- `mine_100_btc: float`

The v0 board has exactly 18 ownable property tiles:

| Tile | City | Type | Buy Price | Energy | Toll | Sell 100% | Mine 100% |
|---:|---|:---:|---:|---:|---:|---:|---:|
| 0 | Irkutsk | A | 34.0 | 8 | 3.40 | 4.0 | 0.75 |
| 1 | Irkutsk | B | 42.0 | 10 | 4.20 | 5.0 | 0.95 |
| 2 | Irkutsk | C | 50.0 | 12 | 5.00 | 6.0 | 1.15 |
| 3 | Patagonia | A | 28.0 | 10 | 2.80 | 3.0 | 0.45 |
| 4 | Patagonia | B | 36.0 | 13 | 3.60 | 4.0 | 0.60 |
| 5 | Patagonia | C | 44.0 | 16 | 4.40 | 5.0 | 0.75 |
| 6 | Ciudad del Este | A | 38.0 | 9 | 3.80 | 6.0 | 0.55 |
| 7 | Ciudad del Este | B | 46.0 | 12 | 4.60 | 8.0 | 0.70 |
| 8 | Ciudad del Este | C | 54.0 | 15 | 5.40 | 10.0 | 0.85 |
| 9 | El Salvador | A | 32.0 | 8 | 3.20 | 4.0 | 0.65 |
| 10 | El Salvador | B | 40.0 | 11 | 4.00 | 6.0 | 0.85 |
| 11 | El Salvador | C | 48.0 | 14 | 4.80 | 8.0 | 1.05 |
| 12 | Angra dos Reis | A | 44.0 | 11 | 4.40 | 8.0 | 0.60 |
| 13 | Angra dos Reis | B | 54.0 | 14 | 5.40 | 11.0 | 0.80 |
| 14 | Angra dos Reis | C | 64.0 | 17 | 6.40 | 14.0 | 1.00 |
| 15 | Atacama | A | 24.0 | 9 | 2.40 | 2.0 | 0.35 |
| 16 | Atacama | B | 32.0 | 12 | 3.20 | 3.0 | 0.50 |
| 17 | Atacama | C | 40.0 | 15 | 4.00 | 4.0 | 0.65 |

City roles:

- Irkutsk: bitcoin / mine specialist
- Patagonia: cheap energy volume with weak conversion
- Ciudad del Este: fiat / sell specialist
- El Salvador: balanced, mining-leaning
- Angra dos Reis: premium fiat / sell specialist
- Atacama: cheapest weak-sell / weak-mine region

There is intentionally no strong-sell / strong-mine city. The strongest
regions are specialists rather than universal best choices.

## Client To Server RPCs

### `rpc_auth(token: String)`

Authenticate a peer against the external auth service. On success the server binds the peer to the JWT `sub`.

Responses:
- `rpc_auth_ok(player_id, exp)`
- `rpc_auth_error(reason)`

### `rpc_join(game_id: String, player_id: String)`

Register the authenticated peer into a match.

Success:
- `rpc_join_accepted(0, player_id, player_index, last_seq)`
- `rpc_player_joined(seq, player_id, player_index)` broadcast

Failure:
- `rpc_action_rejected(0, reason)`

### `rpc_player_ready(game_id: String, player_id: String)`

Marks a player ready in matches that require explicit ready-up before the game starts.

Success:
- `rpc_player_ready_state(seq, player_index, is_ready, ready_count, total_players)` broadcast
- when all required players are ready, normal game-start broadcasts follow

Failure:
- `rpc_action_rejected(0, reason)`

### `rpc_set_player_identity(game_id: String, player_id: String, display_name: String, icon_id: int, color_id: int)`

Sets the waiting-room identity metadata for a player.

The server owns the authoritative identity state and is responsible for
validating:

- short-name length / format
- icon choice bounds
- color choice bounds
- exclusive color reservation across the room

Icons are not exclusive and may be reused by multiple players. Colors are
exclusive and represent the pawn color in the waiting room and later match UI.

Success:
- `rpc_player_identity_changed(seq, player_index, display_name, icon_id, color_id)` broadcast

Failure:
- `rpc_action_rejected(0, reason)` where `reason` may include:
  - `color_unavailable`
  - `invalid_display_name`
  - `invalid_color_id`
  - `invalid_icon_id`
  - `identity_locked`
  - other server-side validation failures

### `rpc_sync_request(game_id: String, player_id: String, last_applied_seq: int)`

Requests authoritative catch-up state after reconnect or late join.

Success:
- `rpc_state_snapshot(0, snapshot)`
- `rpc_sync_complete(0, final_seq)`

Failure:
- `rpc_action_rejected(0, reason)`

### `rpc_roll_dice(game_id: String, player_id: String)`

Current player requests a server-authoritative dice roll.

Typical success broadcast chain:
- `rpc_dice_rolled`
- `rpc_pawn_moved`
- `rpc_tile_landed`
- zero or more follow-up events depending on tile resolution

Failure:
- `rpc_action_rejected(0, reason)`

### `rpc_end_turn(game_id: String, player_id: String)`

Resolve a pending `buy_or_end_turn` or `end_turn` action without buying.

Success:
- `rpc_turn_started(seq, next_player_index, turn_number, cycle)` broadcast

Failure:
- `rpc_action_rejected(0, reason)`

### `rpc_buy_property(game_id: String, player_id: String, tile_index: int)`

Buys the currently pending property if the tile and player match the authoritative pending action.

Success:
- `rpc_property_acquired(seq, player_index, tile_index, price)`
- `rpc_turn_started(seq, next_player_index, turn_number, cycle)`

Failure:
- `rpc_action_rejected(0, reason)`

### `rpc_pay_toll(game_id: String, player_id: String)`

Pays a pending toll using server-stored pending-action metadata.

Success:
- `rpc_toll_paid(seq, payer_index, owner_index, amount)`
- `rpc_turn_started(seq, next_player_index, turn_number, cycle)`

Insufficient fiat path:
- `rpc_action_rejected(0, "insufficient_fiat")`

Failure:
- `rpc_action_rejected(0, reason)`

## Server To Client RPCs

### Session / auth

- `rpc_auth_ok(player_id: String, exp: int)`
- `rpc_auth_error(reason: String)`
- `rpc_join_accepted(seq: int, player_id: String, player_index: int, last_seq: int)`
- `rpc_action_rejected(seq: int, reason: String)`

### Match lifecycle

- `rpc_game_started(seq: int, new_game_id: String)`
- `rpc_board_state(seq: int, board: Dictionary)`
- `rpc_turn_started(seq: int, player_index: int, turn_number: int, cycle: int)`
- `rpc_game_ended(seq: int, winner_index: int, reason: String, btc_goal: float, winner_btc: float)`
- `rpc_player_ready_state(seq: int, player_index: int, is_ready: bool, ready_count: int, total_players: int)`
- `rpc_player_joined(seq: int, player_id: String, player_index: int)`
- `rpc_player_identity_changed(seq: int, player_index: int, display_name: String, icon_id: int, color_id: int)`

### Movement / landing

- `rpc_dice_rolled(seq: int, die_1: int, die_2: int, total: int)`
- `rpc_pawn_moved(seq: int, from_tile: int, to_tile: int, passed_tiles: Array[int])`
- `rpc_tile_landed(seq: int, tile_index: int, tile_type: String, city: String, owner_index: int, toll_due: float, buy_price: float, energy_production: int, sell_100_fiat: float, mine_100_btc: float, action_required: String)`

`rpc_tile_landed` economy fields should match the authoritative tile economy
row for `tile_index`. For self-owned tiles, `toll_due` and `buy_price` are
`0.0`, but the production fields still describe the tile.

`action_required` values currently used by the server:
- `buy_or_end_turn`
- `pay_toll`
- `end_turn`

### Economy / board mutation

- `rpc_player_balance_changed(seq: int, player_index: int, fiat_delta: float, btc_delta: float, reason: String)`
- `rpc_cycle_started(seq: int, cycle: int)`
- `rpc_property_acquired(seq: int, player_index: int, tile_index: int, price: float)`
- `rpc_toll_paid(seq: int, payer_index: int, owner_index: int, amount: float)`

### Reconnect / sync

- `rpc_state_snapshot(seq: int, snapshot: Dictionary)`
- `rpc_sync_complete(seq: int, final_seq: int)`

## Snapshot Shape

`rpc_state_snapshot` is a `Dictionary` intended to contain the authoritative
state needed for reconnect:

- player identities, seat occupancy, and balances
- board/tile state including ownership
- pawn positions
- current player, turn number, and cycle
- pending action metadata
- finished-game metadata when applicable

Current top-level fields include:

- `game_id: String`
- `turn_number: int`
- `current_player_index: int`
- `current_cycle: int`
- `has_started: bool`
- `has_finished: bool`
- `winner_index: int`
- `end_reason: String`
- `board_state: Dictionary`
- `pending_action: Dictionary`
- `players: Array[Dictionary]`
- `ready_count: int`

`pending_action` is empty when no player decision is required. When present,
it should include enough authoritative data for a reconnecting client to render
the current action without recomputing economy values:

- `type: String` - `buy_or_end_turn`, `pay_toll`, or `end_turn`
- `tile_index: int`
- `owner_index: int`
- `amount: float` - toll due for `pay_toll`, otherwise `0.0`
- `buy_price: float` - buy price for `buy_or_end_turn`, otherwise `0.0`
- `energy_production: int`
- `sell_100_fiat: float`
- `mine_100_btc: float`

`board_state.tiles` contains exactly 18 property entries. Each tile entry
should include:

- `tile_index: int`
- `tile_type: String` - `A`, `B`, or `C`
- `city: String`
- `owner_index: int` - `-1` when unowned
- `buy_price: float`
- `energy_production: int`
- `toll: float`
- `sell_100_fiat: float`
- `mine_100_btc: float`

Each `players` entry is authoritative per-seat state and currently includes:

- `player_index: int`
- `player_id: String`
- `joined: bool`
- `ready: bool`
- `display_name: String`
- `icon_id: int`
- `color_id: int`
- `fiat_balance: float`
- `energy_balance: int`
- `bitcoin_balance: float`
- `sell_percent: int`
- `position: int`
- `laps: int`

Clients should treat `players[*].joined` and `players[*].ready` as the
canonical waiting-room seat state and should not depend on a separate
top-level ready array.

Clients should also treat `players[*].display_name`, `players[*].icon_id`, and
`players[*].color_id` as the canonical waiting-room identity state. Colors are
exclusive across joined players; icons are not.
