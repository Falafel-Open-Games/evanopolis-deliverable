class_name NetworkClient
extends "res://scripts/client.gd"

var server_node: Node
var peer_id: int = 0


func _init(server_host: Node, peer: int) -> void:
    server_node = server_host
    peer_id = peer
    assert(server_node)
    assert(peer_id > 0)


func rpc_game_started(seq: int, new_game_id: String) -> void:
    server_node.rpc_id(peer_id, "rpc_game_started", seq, new_game_id)


func rpc_board_state(seq: int, board: Dictionary) -> void:
    server_node.rpc_id(peer_id, "rpc_board_state", seq, board)


func rpc_turn_started(seq: int, player_index: int, turn_number: int, cycle: int) -> void:
    server_node.rpc_id(peer_id, "rpc_turn_started", seq, player_index, turn_number, cycle)


func rpc_game_ended(seq: int, winner_index: int, reason: String, btc_goal: float, winner_btc: float) -> void:
    server_node.rpc_id(peer_id, "rpc_game_ended", seq, winner_index, reason, btc_goal, winner_btc)


func rpc_player_ready_state(seq: int, player_index: int, is_ready: bool, ready_count: int, total_players: int) -> void:
    server_node.rpc_id(peer_id, "rpc_player_ready_state", seq, player_index, is_ready, ready_count, total_players)


func rpc_player_joined(seq: int, player_id: String, player_index: int) -> void:
    server_node.rpc_id(peer_id, "rpc_player_joined", seq, player_id, player_index)


func rpc_player_identity_changed(seq: int, player_index: int, display_name: String, icon_id: int, color_id: int) -> void:
    server_node.rpc_id(peer_id, "rpc_player_identity_changed", seq, player_index, display_name, icon_id, color_id)


func rpc_dice_rolled(seq: int, die_1: int, die_2: int, total: int) -> void:
    server_node.rpc_id(peer_id, "rpc_dice_rolled", seq, die_1, die_2, total)


func rpc_pawn_moved(seq: int, from_tile: int, to_tile: int, passed_tiles: Array[int]) -> void:
    server_node.rpc_id(peer_id, "rpc_pawn_moved", seq, from_tile, to_tile, passed_tiles)


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
    server_node.rpc_id(peer_id, "rpc_tile_landed", seq, tile_index, tile_type, city, owner_index, toll_due, buy_price, action_required)


func rpc_incident_drawn(seq: int, tile_index: int, incident_kind: String, card_id: String, card_text: String) -> void:
    server_node.rpc_id(peer_id, "rpc_incident_drawn", seq, tile_index, incident_kind, card_id, card_text)


func rpc_player_balance_changed(seq: int, player_index: int, fiat_delta: float, btc_delta: float, reason: String) -> void:
    server_node.rpc_id(peer_id, "rpc_player_balance_changed", seq, player_index, fiat_delta, btc_delta, reason)


func rpc_cycle_started(seq: int, cycle: int, inflation_active: bool) -> void:
    server_node.rpc_id(peer_id, "rpc_cycle_started", seq, cycle, inflation_active)


func rpc_incident_type_changed(seq: int, tile_index: int, incident_kind: String) -> void:
    server_node.rpc_id(peer_id, "rpc_incident_type_changed", seq, tile_index, incident_kind)


func rpc_property_acquired(seq: int, player_index: int, tile_index: int, price: float) -> void:
    server_node.rpc_id(peer_id, "rpc_property_acquired", seq, player_index, tile_index, price)


func rpc_miner_batches_added(seq: int, player_index: int, tile_index: int, count: int) -> void:
    server_node.rpc_id(peer_id, "rpc_miner_batches_added", seq, player_index, tile_index, count)


func rpc_mining_reward(
        seq: int,
        owner_index: int,
        tile_index: int,
        miner_batches: int,
        btc_reward: float,
        reason: String,
) -> void:
    server_node.rpc_id(peer_id, "rpc_mining_reward", seq, owner_index, tile_index, miner_batches, btc_reward, reason)


func rpc_toll_paid(seq: int, payer_index: int, owner_index: int, amount: float) -> void:
    server_node.rpc_id(peer_id, "rpc_toll_paid", seq, payer_index, owner_index, amount)


func rpc_player_sent_to_inspection(seq: int, player_index: int, reason: String) -> void:
    server_node.rpc_id(peer_id, "rpc_player_sent_to_inspection", seq, player_index, reason)


func rpc_inspection_voucher_granted(seq: int, player_index: int, amount: int, reason: String) -> void:
    server_node.rpc_id(peer_id, "rpc_inspection_voucher_granted", seq, player_index, amount, reason)


func rpc_state_snapshot(seq: int, snapshot: Dictionary) -> void:
    server_node.rpc_id(peer_id, "rpc_state_snapshot", seq, snapshot)


func rpc_sync_complete(seq: int, final_seq: int) -> void:
    server_node.rpc_id(peer_id, "rpc_sync_complete", seq, final_seq)


func rpc_action_rejected(seq: int, reason: String) -> void:
    server_node.rpc_id(peer_id, "rpc_action_rejected", seq, reason)
