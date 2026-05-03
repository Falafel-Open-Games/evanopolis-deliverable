class_name HeadlessRpc
extends Node

@rpc("any_peer")
func rpc_join(game_id: String, player_id: String) -> void:
    _handle_join(game_id, player_id)


@rpc("any_peer")
func rpc_auth(token: String) -> void:
    _handle_auth(token)


@rpc("any_peer")
func rpc_roll_dice(game_id: String, player_id: String) -> void:
    _handle_roll_dice(game_id, player_id)


@rpc("any_peer")
func rpc_end_turn(game_id: String, player_id: String) -> void:
    _handle_end_turn(game_id, player_id)


@rpc("any_peer")
func rpc_buy_property(game_id: String, player_id: String, tile_index: int) -> void:
    _handle_buy_property(game_id, player_id, tile_index)


@rpc("any_peer")
func rpc_pay_toll(game_id: String, player_id: String) -> void:
    _handle_pay_toll(game_id, player_id)


@rpc("any_peer")
func rpc_sync_request(game_id: String, player_id: String, last_applied_seq: int) -> void:
    _handle_sync_request(game_id, player_id, last_applied_seq)


@rpc("any_peer")
func rpc_player_ready(game_id: String, player_id: String) -> void:
    _handle_player_ready(game_id, player_id)


@rpc("any_peer")
func rpc_set_player_identity(game_id: String, player_id: String, display_name: String, icon_id: int, color_id: int) -> void:
    _handle_set_player_identity(game_id, player_id, display_name, icon_id, color_id)


@rpc("authority")
func rpc_game_started(seq: int, new_game_id: String) -> void:
    _handle_game_started(seq, new_game_id)


@rpc("authority")
func rpc_board_state(seq: int, board: Dictionary) -> void:
    _handle_board_state(seq, board)


@rpc("authority")
func rpc_auth_ok(player_id: String, exp: int) -> void:
    _handle_auth_ok(player_id, exp)


@rpc("authority")
func rpc_auth_error(reason: String) -> void:
    _handle_auth_error(reason)


@rpc("authority")
func rpc_join_accepted(seq: int, player_id: String, player_index: int, last_seq: int) -> void:
    _handle_join_accepted(seq, player_id, player_index, last_seq)


@rpc("authority")
func rpc_turn_started(seq: int, player_index: int, turn_number: int, cycle: int) -> void:
    _handle_turn_started(seq, player_index, turn_number, cycle)


@rpc("authority")
func rpc_game_ended(seq: int, winner_index: int, reason: String, btc_goal: float, winner_btc: float) -> void:
    _handle_game_ended(seq, winner_index, reason, btc_goal, winner_btc)


@rpc("authority")
func rpc_player_ready_state(seq: int, player_index: int, is_ready: bool, ready_count: int, total_players: int) -> void:
    _handle_player_ready_state(seq, player_index, is_ready, ready_count, total_players)


@rpc("authority")
func rpc_player_joined(seq: int, player_id: String, player_index: int) -> void:
    _handle_player_joined(seq, player_id, player_index)


@rpc("authority")
func rpc_player_identity_changed(seq: int, player_index: int, display_name: String, icon_id: int, color_id: int) -> void:
    _handle_player_identity_changed(seq, player_index, display_name, icon_id, color_id)


@rpc("authority")
func rpc_dice_rolled(seq: int, die_1: int, die_2: int, total: int) -> void:
    _handle_dice_rolled(seq, die_1, die_2, total)


@rpc("authority")
func rpc_pawn_moved(seq: int, from_tile: int, to_tile: int, passed_tiles: Array[int]) -> void:
    _handle_pawn_moved(seq, from_tile, to_tile, passed_tiles)


@rpc("authority")
func rpc_tile_landed(
        seq: int,
        tile_index: int,
        tile_type: String,
        city: String,
        owner_index: int,
        toll_due: float,
        buy_price: float,
        energy_production: int,
        sell_100_fiat: float,
        mine_100_btc: float,
        action_required: String,
) -> void:
    _handle_tile_landed(seq, tile_index, tile_type, city, owner_index, toll_due, buy_price, energy_production, sell_100_fiat, mine_100_btc, action_required)


@rpc("authority")
func rpc_player_balance_changed(seq: int, player_index: int, fiat_delta: float, btc_delta: float, reason: String) -> void:
    _handle_player_balance_changed(seq, player_index, fiat_delta, btc_delta, reason)


@rpc("authority")
func rpc_cycle_started(seq: int, cycle: int) -> void:
    _handle_cycle_started(seq, cycle)


@rpc("authority")
func rpc_property_acquired(seq: int, player_index: int, tile_index: int, price: float) -> void:
    _handle_property_acquired(seq, player_index, tile_index, price)


@rpc("authority")
func rpc_toll_paid(seq: int, payer_index: int, owner_index: int, amount: float) -> void:
    _handle_toll_paid(seq, payer_index, owner_index, amount)


@rpc("authority")
func rpc_state_snapshot(seq: int, snapshot: Dictionary) -> void:
    _handle_state_snapshot(seq, snapshot)


@rpc("authority")
func rpc_sync_complete(seq: int, final_seq: int) -> void:
    _handle_sync_complete(seq, final_seq)


@rpc("authority")
func rpc_action_rejected(seq: int, reason: String) -> void:
    _handle_action_rejected(seq, reason)


func _handle_join(game_id: String, player_id: String) -> void:
    pass


func _handle_auth(token: String) -> void:
    pass


func _handle_roll_dice(game_id: String, player_id: String) -> void:
    pass


func _handle_end_turn(game_id: String, player_id: String) -> void:
    pass


func _handle_buy_property(game_id: String, player_id: String, tile_index: int) -> void:
    pass


func _handle_pay_toll(game_id: String, player_id: String) -> void:
    pass


func _handle_sync_request(game_id: String, player_id: String, last_applied_seq: int) -> void:
    pass


func _handle_player_ready(game_id: String, player_id: String) -> void:
    pass


func _handle_set_player_identity(game_id: String, player_id: String, display_name: String, icon_id: int, color_id: int) -> void:
    pass


func _handle_game_started(seq: int, new_game_id: String) -> void:
    pass


func _handle_board_state(seq: int, board: Dictionary) -> void:
    pass


func _handle_auth_ok(player_id: String, exp: int) -> void:
    pass


func _handle_auth_error(reason: String) -> void:
    pass


func _handle_join_accepted(seq: int, player_id: String, player_index: int, last_seq: int) -> void:
    pass


func _handle_turn_started(seq: int, player_index: int, turn_number: int, cycle: int) -> void:
    pass


func _handle_game_ended(seq: int, winner_index: int, reason: String, btc_goal: float, winner_btc: float) -> void:
    pass


func _handle_player_ready_state(seq: int, player_index: int, is_ready: bool, ready_count: int, total_players: int) -> void:
    pass


func _handle_player_joined(seq: int, player_id: String, player_index: int) -> void:
    pass


func _handle_player_identity_changed(seq: int, player_index: int, display_name: String, icon_id: int, color_id: int) -> void:
    pass


func _handle_dice_rolled(seq: int, die_1: int, die_2: int, total: int) -> void:
    pass


func _handle_pawn_moved(seq: int, from_tile: int, to_tile: int, passed_tiles: Array[int]) -> void:
    pass


func _handle_tile_landed(
        seq: int,
        tile_index: int,
        tile_type: String,
        city: String,
        owner_index: int,
        toll_due: float,
        buy_price: float,
        energy_production: int,
        sell_100_fiat: float,
        mine_100_btc: float,
        action_required: String,
) -> void:
    pass


func _handle_player_balance_changed(seq: int, player_index: int, fiat_delta: float, btc_delta: float, reason: String) -> void:
    pass


func _handle_cycle_started(seq: int, cycle: int) -> void:
    pass


func _handle_property_acquired(seq: int, player_index: int, tile_index: int, price: float) -> void:
    pass


func _handle_toll_paid(seq: int, payer_index: int, owner_index: int, amount: float) -> void:
    pass


func _handle_state_snapshot(seq: int, snapshot: Dictionary) -> void:
    pass


func _handle_sync_complete(seq: int, final_seq: int) -> void:
    pass


func _handle_action_rejected(seq: int, reason: String) -> void:
    pass
