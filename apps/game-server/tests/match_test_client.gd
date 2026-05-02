extends "res://scripts/client.gd"

class_name MatchTestClient

var events: Array[Dictionary] = []


func rpc_game_started(seq: int, new_game_id: String) -> void:
    events.append(
        {
            "method": "rpc_game_started",
            "seq": seq,
            "game_id": new_game_id,
        },
    )


func rpc_board_state(seq: int, board: Dictionary) -> void:
    events.append(
        {
            "method": "rpc_board_state",
            "seq": seq,
            "board": board,
        },
    )


func rpc_turn_started(seq: int, player_index: int, turn_number: int, cycle: int) -> void:
    events.append(
        {
            "method": "rpc_turn_started",
            "seq": seq,
            "player_index": player_index,
            "turn_number": turn_number,
            "cycle": cycle,
        },
    )


func rpc_game_ended(seq: int, winner_index: int, reason: String, btc_goal: float, winner_btc: float) -> void:
    events.append(
        {
            "method": "rpc_game_ended",
            "seq": seq,
            "winner_index": winner_index,
            "reason": reason,
            "btc_goal": btc_goal,
            "winner_btc": winner_btc,
        },
    )


func rpc_player_ready_state(seq: int, player_index: int, is_ready: bool, ready_count: int, total_players: int) -> void:
    events.append(
        {
            "method": "rpc_player_ready_state",
            "seq": seq,
            "player_index": player_index,
            "is_ready": is_ready,
            "ready_count": ready_count,
            "total_players": total_players,
        },
    )


func rpc_player_joined(seq: int, player_id: String, player_index: int) -> void:
    events.append(
        {
            "method": "rpc_player_joined",
            "seq": seq,
            "player_id": player_id,
            "player_index": player_index,
        },
    )


func rpc_player_identity_changed(seq: int, player_index: int, display_name: String, icon_id: int, color_id: int) -> void:
    events.append(
        {
            "method": "rpc_player_identity_changed",
            "seq": seq,
            "player_index": player_index,
            "display_name": display_name,
            "icon_id": icon_id,
            "color_id": color_id,
        },
    )


func rpc_dice_rolled(seq: int, die_1: int, die_2: int, total: int) -> void:
    events.append(
        {
            "method": "rpc_dice_rolled",
            "seq": seq,
            "die_1": die_1,
            "die_2": die_2,
            "total": total,
        },
    )


func rpc_pawn_moved(seq: int, from_tile: int, to_tile: int, passed_tiles: Array[int]) -> void:
    events.append(
        {
            "method": "rpc_pawn_moved",
            "seq": seq,
            "from_tile": from_tile,
            "to_tile": to_tile,
            "passed_tiles": passed_tiles,
        },
    )


func rpc_tile_landed(
        seq: int,
        tile_index: int,
        tile_type: String,
        city: String,
        owner_index: int,
        toll_due: float,
        buy_price: float,
        action_required: String,
) -> void:
    events.append(
        {
            "method": "rpc_tile_landed",
            "seq": seq,
            "tile_index": tile_index,
            "tile_type": tile_type,
            "city": city,
            "owner_index": owner_index,
            "toll_due": toll_due,
            "buy_price": buy_price,
            "action_required": action_required,
        },
    )


func rpc_player_balance_changed(seq: int, player_index: int, fiat_delta: float, btc_delta: float, reason: String) -> void:
    events.append(
        {
            "method": "rpc_player_balance_changed",
            "seq": seq,
            "player_index": player_index,
            "fiat_delta": fiat_delta,
            "btc_delta": btc_delta,
            "reason": reason,
        },
    )


func rpc_cycle_started(seq: int, cycle: int, inflation_active: bool) -> void:
    events.append(
        {
            "method": "rpc_cycle_started",
            "seq": seq,
            "cycle": cycle,
            "inflation_active": inflation_active,
        },
    )


func rpc_property_acquired(seq: int, player_index: int, tile_index: int, price: float) -> void:
    events.append(
        {
            "method": "rpc_property_acquired",
            "seq": seq,
            "player_index": player_index,
            "tile_index": tile_index,
            "price": price,
        },
    )


func rpc_toll_paid(seq: int, payer_index: int, owner_index: int, amount: float) -> void:
    events.append(
        {
            "method": "rpc_toll_paid",
            "seq": seq,
            "payer_index": payer_index,
            "owner_index": owner_index,
            "amount": amount,
        },
    )


func rpc_state_snapshot(seq: int, snapshot: Dictionary) -> void:
    events.append(
        {
            "method": "rpc_state_snapshot",
            "seq": seq,
            "snapshot": snapshot,
        },
    )


func rpc_sync_complete(seq: int, final_seq: int) -> void:
    events.append(
        {
            "method": "rpc_sync_complete",
            "seq": seq,
            "final_seq": final_seq,
        },
    )


func rpc_action_rejected(seq: int, reason: String) -> void:
    events.append(
        {
            "method": "rpc_action_rejected",
            "seq": seq,
            "reason": reason,
        },
    )
