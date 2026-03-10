class_name HeadlessServer
extends RefCounted

const GameMatch = preload("res://scripts/match.gd")
const NetworkClient = preload("res://scripts/network_client.gd")
const Config = preload("res://scripts/config.gd")


class NullClient:
    extends Client

    func rpc_game_started(_seq: int, _new_game_id: String) -> void:
        pass


    func rpc_board_state(_seq: int, _board: Dictionary) -> void:
        pass


    func rpc_turn_started(_seq: int, _player_index: int, _turn_number: int, _cycle: int) -> void:
        pass


    func rpc_game_ended(_seq: int, _winner_index: int, _reason: String, _btc_goal: float, _winner_btc: float) -> void:
        pass


    func rpc_player_ready_state(_seq: int, _player_index: int, _is_ready: bool, _ready_count: int, _total_players: int) -> void:
        pass


    func rpc_player_joined(_seq: int, _player_id: String, _player_index: int) -> void:
        pass


    func rpc_dice_rolled(_seq: int, _die_1: int, _die_2: int, _total: int) -> void:
        pass


    func rpc_pawn_moved(_seq: int, _from_tile: int, _to_tile: int, _passed_tiles: Array[int]) -> void:
        pass


    func rpc_tile_landed(
            _seq: int,
            _tile_index: int,
            _tile_type: String,
            _city: String,
            _owner_index: int,
            _toll_due: float,
            _buy_price: float,
            _action_required: String,
    ) -> void:
        pass


    func rpc_incident_drawn(_seq: int, _tile_index: int, _incident_kind: String, _card_id: String, _card_text: String) -> void:
        pass


    func rpc_player_balance_changed(_seq: int, _player_index: int, _fiat_delta: float, _btc_delta: float, _reason: String) -> void:
        pass


    func rpc_cycle_started(_seq: int, _cycle: int, _inflation_active: bool) -> void:
        pass


    func rpc_incident_type_changed(_seq: int, _tile_index: int, _incident_kind: String) -> void:
        pass


    func rpc_property_acquired(_seq: int, _player_index: int, _tile_index: int, _price: float) -> void:
        pass


    func rpc_miner_batches_added(_seq: int, _player_index: int, _tile_index: int, _count: int) -> void:
        pass


    func rpc_mining_reward(
            _seq: int,
            _owner_index: int,
            _tile_index: int,
            _miner_batches: int,
            _btc_reward: float,
            _reason: String,
    ) -> void:
        pass


    func rpc_toll_paid(_seq: int, _payer_index: int, _owner_index: int, _amount: float) -> void:
        pass


    func rpc_player_sent_to_inspection(_seq: int, _player_index: int, _reason: String) -> void:
        pass


    func rpc_inspection_voucher_granted(_seq: int, _player_index: int, _amount: int, _reason: String) -> void:
        pass


    func rpc_state_snapshot(_seq: int, _snapshot: Dictionary) -> void:
        pass


    func rpc_sync_complete(_seq: int, _final_seq: int) -> void:
        pass


    func rpc_action_rejected(_seq: int, _reason: String) -> void:
        pass


var matches: Dictionary
var peer_slots: Dictionary
var authorized_peers: Dictionary


func _init() -> void:
    matches = { }
    peer_slots = { }
    authorized_peers = { }


func create_match(config: Config, require_explicit_ready: bool = false) -> GameMatch:
    var game_match: GameMatch = GameMatch.new(config, [], require_explicit_ready)
    matches[config.game_id] = game_match
    return game_match


func register_remote_client(game_id: String, player_id: String, peer_id: int, server_node: Node) -> Dictionary:
    var authorized_player_id: String = str(authorized_peers.get(peer_id, ""))
    if authorized_player_id.is_empty() or authorized_player_id != player_id:
        return { "reason": "unauthorized", "player_index": -1, "seq": 0 }
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "player_index": -1, "seq": 0 }
    if peer_slots.has(peer_id):
        return { "reason": "peer_already_registered", "player_index": -1, "seq": 0 }
    var client: Client
    if server_node == null:
        client = NullClient.new()
    else:
        client = NetworkClient.new(server_node, peer_id)
    var result: Dictionary = game_match.assign_client(player_id, client)
    var reason: String = str(result.get("reason", ""))
    if not reason.is_empty():
        result["seq"] = 0
        return result
    var replaced_peer_id: int = _remove_existing_peer_slot(game_id, player_id, peer_id)
    result["replaced_peer_id"] = replaced_peer_id
    result["last_seq"] = game_match.last_sequence()
    peer_slots[peer_id] = {
        "game_id": game_id,
        "player_id": player_id,
        "player_index": int(result.get("player_index", -1)),
    }
    result["seq"] = 0
    return result


func authorize_peer(peer_id: int, player_id: String) -> void:
    authorized_peers[peer_id] = player_id


func revoke_peer(peer_id: int) -> void:
    var slot: Dictionary = peer_slots.get(peer_id, { })
    if not slot.is_empty():
        var game_id: String = str(slot.get("game_id", ""))
        var player_id: String = str(slot.get("player_id", ""))
        var player_index: int = int(slot.get("player_index", -1))
        var game_match: GameMatch = matches.get(game_id, null)
        if game_match != null:
            game_match.detach_client(player_id, player_index)
    authorized_peers.erase(peer_id)
    peer_slots.erase(peer_id)


func handle_peer_disconnected(peer_id: int) -> void:
    revoke_peer(peer_id)


func rpc_roll_dice(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if slot.get("game_id", "") != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    game_match.rpc_roll_dice(game_id, player_id)
    return { "reason": "", "seq": 0 }


func rpc_player_ready(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if slot.get("game_id", "") != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_player_ready(game_id, player_id)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_end_turn(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_end_turn(game_id, player_id)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_buy_property(game_id: String, player_id: String, tile_index: int, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_buy_property(game_id, player_id, tile_index)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_buy_miner_batch(game_id: String, player_id: String, tile_index: int, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_buy_miner_batch(game_id, player_id, tile_index)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_pay_toll(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_pay_toll(game_id, player_id)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_pay_inspection_fee(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_pay_inspection_fee(game_id, player_id)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_roll_inspection_exit(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_roll_inspection_exit(game_id, player_id)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_use_inspection_voucher(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    var reason: String = game_match.rpc_use_inspection_voucher(game_id, player_id)
    if not reason.is_empty():
        return { "reason": reason, "seq": 0 }
    return { "reason": "", "seq": 0 }


func rpc_sync_request(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
    var game_match: GameMatch = matches.get(game_id, null)
    if game_match == null:
        return { "reason": "invalid_game_id", "seq": 0 }
    if sender_peer_id >= 0:
        var slot: Dictionary = peer_slots.get(sender_peer_id, { })
        if slot.is_empty():
            return { "reason": "unregistered_peer", "seq": 0 }
        if str(slot.get("game_id", "")) != game_id:
            return { "reason": "peer_game_id_mismatch", "seq": 0 }
        if str(slot.get("player_id", "")) != player_id:
            return { "reason": "peer_player_mismatch", "seq": 0 }
    return {
        "reason": "",
        "seq": 0,
        "snapshot": game_match.build_state_snapshot(),
        "final_seq": game_match.last_sequence(),
    }


func _remove_existing_peer_slot(game_id: String, player_id: String, new_peer_id: int) -> int:
    for existing_peer_id in peer_slots.keys():
        var peer_id_value: int = int(existing_peer_id)
        if peer_id_value == new_peer_id:
            continue
        var slot: Dictionary = peer_slots[existing_peer_id]
        if str(slot.get("game_id", "")) != game_id:
            continue
        if str(slot.get("player_id", "")) != player_id:
            continue
        peer_slots.erase(existing_peer_id)
        return peer_id_value
    return -1
