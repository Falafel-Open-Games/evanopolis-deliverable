extends "res://scripts/headless_rpc.gd"

const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int = 9010
const EconomyV0 = preload("res://scripts/rules/economy_v0.gd")
const ANSI_RESET: String = "\u001b[0m"
const ANSI_BOLD: String = "\u001b[1m"
const ANSI_RED: String = "\u001b[31m"
const ANSI_GREEN: String = "\u001b[32m"
const ANSI_YELLOW: String = "\u001b[33m"

var host: String = DEFAULT_HOST
var port: int = DEFAULT_PORT
var game_id: String = ""
var player_id: String = ""
var auth_token: String = ""
var player_index: int = -1
var current_player_index: int = 0
var current_turn_number: int = 0
var current_cycle_number: int = 0
var pending_action_type: String = ""
var pending_action_tile_index: int = -1
var pending_action_owner_index: int = -1
var pending_action_amount: float = 0.0
var pending_action_buy_price: float = 0.0
var match_has_started: bool = false
var match_has_finished: bool = false
var match_winner_index: int = -1
var match_end_reason: String = ""
var board_state: Dictionary = { }
var pending_game_started: bool = false
var next_expected_seq: int = 1
var pending_events: Dictionary = { }
var sync_in_progress: bool = false
var connected_player_indexes: Dictionary = { }
var player_fiat_balances: Dictionary = { }
var player_bitcoin_balances: Dictionary = { }
var player_positions: Dictionary = { }
var player_in_inspection: Dictionary = { }
var player_inspection_free_exits: Dictionary = { }
var player_ready_states: Dictionary = { }
var local_ready_sent: bool = false


func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_args()
    _parse_args(args)
    assert(not game_id.is_empty())
    assert(not auth_token.is_empty())
    _connect_to_server()


func _parse_args(args: PackedStringArray) -> void:
    var index: int = 0
    while index < args.size():
        var arg: String = args[index]
        if arg == "--host" and index + 1 < args.size():
            host = args[index + 1]
            index += 2
            continue
        if arg == "--port" and index + 1 < args.size():
            port = int(args[index + 1])
            index += 2
            continue
        if arg == "--game-id" and index + 1 < args.size():
            game_id = args[index + 1]
            index += 2
            continue
        if arg == "--auth-token" and index + 1 < args.size():
            auth_token = args[index + 1]
            index += 2
            continue
        if arg == "--player-id":
            _log_note("--player-id is no longer supported; player_id is derived from JWT sub")
            _exit_with_code(1)
            return
        index += 1


func _connect_to_server() -> void:
    var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
    var result: int = peer.create_client("ws://%s:%d" % [host, port])
    assert(result == OK)
    multiplayer.multiplayer_peer = peer
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    print("client: connecting to %s:%d" % [host, port])


func _on_connected_to_server() -> void:
    print("client: connected")
    _rpc_to_server("rpc_auth", [auth_token])


func _on_connection_failed() -> void:
    print("client: connection failed")
    _exit_with_code(1)


func _on_server_disconnected() -> void:
    print("client: server disconnected")
    _exit_with_code(1)


func _exit_with_code(code: int) -> void:
    get_tree().quit(code)


func _handle_game_started(seq: int, new_game_id: String) -> void:
    _queue_event(seq, "_apply_game_started", [new_game_id])


func _handle_board_state(seq: int, board: Dictionary) -> void:
    _queue_event(seq, "_apply_board_state", [board])


func _handle_auth_ok(authorized_player_id: String, exp: int) -> void:
    _apply_auth_ok(authorized_player_id, exp)


func _handle_auth_error(reason: String) -> void:
    _apply_auth_error(reason)


func _handle_join_accepted(seq: int, accepted_player_id: String, assigned_player_index: int, last_seq: int) -> void:
    _queue_event(seq, "_apply_join_accepted", [accepted_player_id, assigned_player_index, last_seq])


func _handle_turn_started(seq: int, player_index_value: int, turn_number: int, cycle: int) -> void:
    _queue_event(seq, "_apply_turn_started", [player_index_value, turn_number, cycle])


func _handle_player_ready_state(seq: int, player_index_value: int, is_ready: bool, ready_count: int, total_players: int) -> void:
    _queue_event(seq, "_apply_player_ready_state", [player_index_value, is_ready, ready_count, total_players])


func _handle_game_ended(seq: int, winner_index: int, reason: String, btc_goal: float, winner_btc: float) -> void:
    _queue_event(seq, "_apply_game_ended", [winner_index, reason, btc_goal, winner_btc])


func _handle_player_joined(seq: int, player_id_value: String, player_index_value: int) -> void:
    _queue_event(seq, "_apply_player_joined", [player_id_value, player_index_value])


func _handle_dice_rolled(seq: int, die_1: int, die_2: int, total: int) -> void:
    _queue_event(seq, "_apply_dice_rolled", [die_1, die_2, total])


func _handle_pawn_moved(seq: int, from_tile: int, to_tile: int, passed_tiles: Array[int]) -> void:
    _queue_event(seq, "_apply_pawn_moved", [from_tile, to_tile, passed_tiles])


func _handle_tile_landed(
        seq: int,
        tile_index: int,
        tile_type: String,
        city: String,
        owner_index: int,
        toll_due: float,
        buy_price: float,
        action_required: String,
) -> void:
    _queue_event(seq, "_apply_tile_landed", [tile_index, tile_type, city, owner_index, toll_due, buy_price, action_required])


func _handle_incident_drawn(seq: int, tile_index: int, incident_kind: String, card_id: String, card_text: String) -> void:
    _queue_event(seq, "_apply_incident_drawn", [tile_index, incident_kind, card_id, card_text])


func _handle_player_balance_changed(seq: int, player_index_value: int, fiat_delta: float, btc_delta: float, reason: String) -> void:
    _queue_event(seq, "_apply_player_balance_changed", [player_index_value, fiat_delta, btc_delta, reason])


func _handle_cycle_started(seq: int, cycle: int, inflation_active: bool) -> void:
    _queue_event(seq, "_apply_cycle_started", [cycle, inflation_active])


func _handle_incident_type_changed(seq: int, tile_index: int, incident_kind: String) -> void:
    _queue_event(seq, "_apply_incident_type_changed", [tile_index, incident_kind])


func _handle_property_acquired(seq: int, owner_player_index: int, tile_index: int, price: float) -> void:
    _queue_event(seq, "_apply_property_acquired", [owner_player_index, tile_index, price])


func _handle_miner_batches_added(seq: int, owner_player_index: int, tile_index: int, count: int) -> void:
    _queue_event(seq, "_apply_miner_batches_added", [owner_player_index, tile_index, count])


func _handle_mining_reward(
        seq: int,
        owner_index: int,
        tile_index: int,
        miner_batches: int,
        btc_reward: float,
        reason: String,
) -> void:
    _queue_event(seq, "_apply_mining_reward", [owner_index, tile_index, miner_batches, btc_reward, reason])


func _handle_toll_paid(seq: int, payer_index: int, owner_index: int, amount: float) -> void:
    _queue_event(seq, "_apply_toll_paid", [payer_index, owner_index, amount])


func _handle_player_sent_to_inspection(seq: int, player_index_value: int, reason: String) -> void:
    _queue_event(seq, "_apply_player_sent_to_inspection", [player_index_value, reason])


func _handle_inspection_voucher_granted(seq: int, player_index_value: int, amount: int, reason: String) -> void:
    _queue_event(seq, "_apply_inspection_voucher_granted", [player_index_value, amount, reason])


func _handle_state_snapshot(seq: int, snapshot: Dictionary) -> void:
    _queue_event(seq, "_apply_state_snapshot", [snapshot])


func _handle_sync_complete(seq: int, final_seq: int) -> void:
    _queue_event(seq, "_apply_sync_complete", [final_seq])


func _handle_action_rejected(seq: int, reason: String) -> void:
    _queue_event(seq, "_apply_action_rejected", [reason])


func _queue_event(seq: int, method: String, args: Array) -> void:
    if seq <= 0:
        callv(method, args)
        return
    if seq < next_expected_seq:
        return
    pending_events[seq] = { "method": method, "args": args }
    if player_index < 0:
        return
    if sync_in_progress:
        return
    _flush_events()


func _flush_events() -> int:
    var applied_count: int = 0
    while pending_events.has(next_expected_seq):
        var entry: Dictionary = pending_events[next_expected_seq]
        pending_events.erase(next_expected_seq)
        callv(str(entry.get("method", "")), entry.get("args", []))
        next_expected_seq += 1
        applied_count += 1
    return applied_count


func _apply_game_started(new_game_id: String) -> void:
    game_id = new_game_id
    match_has_started = true
    local_ready_sent = false
    match_has_finished = false
    match_winner_index = -1
    match_end_reason = ""
    if player_index < 0:
        pending_game_started = true
        return
    _log_server("%sgame started%s: game_id=%s" % [ANSI_GREEN, ANSI_RESET, game_id])


func _apply_board_state(board: Dictionary) -> void:
    board_state = board
    var size: int = int(board_state.get("size", 0))
    _log_server("board state: size=%d" % size)


func _apply_auth_ok(authorized_player_id: String, exp: int) -> void:
    if player_id.is_empty():
        player_id = authorized_player_id
    if player_id != authorized_player_id:
        _log_note("auth mismatch: expected %s got %s" % [player_id, authorized_player_id])
        multiplayer.multiplayer_peer.close()
        return
    _log_server("auth ok: player_id=%s exp=%d" % [player_id, exp])
    _rpc_to_server("rpc_join", [game_id, player_id])


func _apply_auth_error(reason: String) -> void:
    _log_note("auth error: reason=%s" % reason)
    multiplayer.multiplayer_peer.close()


func _apply_join_accepted(accepted_player_id: String, assigned_player_index: int, last_seq: int) -> void:
    if accepted_player_id != player_id:
        return
    player_index = assigned_player_index
    _log_server("join accepted: player_id=%s player_index=%d" % [player_id, player_index])
    sync_in_progress = true
    var last_applied_seq: int = next_expected_seq - 1
    _rpc_to_server("rpc_sync_request", [game_id, player_id, last_applied_seq])


func _apply_turn_started(player_index_value: int, turn_number: int, cycle: int) -> void:
    if match_has_finished:
        return
    current_player_index = player_index_value
    current_turn_number = turn_number
    current_cycle_number = cycle
    pending_action_type = ""
    pending_action_tile_index = -1
    pending_action_owner_index = -1
    pending_action_amount = 0.0
    pending_action_buy_price = 0.0
    var connected_players_summary: String = _build_connected_players_summary()
    _log_server(
        "%sturn started%s: player=%d, turn=%d, cycle=%d, connected_players=[%s]"
        % [ANSI_GREEN, ANSI_RESET, player_index_value, turn_number, cycle, connected_players_summary],
    )
    if player_index_value != player_index:
        return
    if bool(player_in_inspection.get(player_index_value, false)):
        await _start_inspection_resolution_prompt()
        return
    await _start_turn_prompt()


func _apply_player_ready_state(player_index_value: int, is_ready: bool, ready_count: int, total_players: int) -> void:
    player_ready_states[player_index_value] = is_ready
    _log_server(
        "player ready: player=%d ready=%s ready_count=%d/%d"
        % [player_index_value, is_ready, ready_count, total_players],
    )


func _apply_game_ended(winner_index: int, reason: String, btc_goal: float, winner_btc: float) -> void:
    match_has_finished = true
    match_winner_index = winner_index
    match_end_reason = reason
    pending_action_type = ""
    pending_action_tile_index = -1
    pending_action_owner_index = -1
    pending_action_amount = 0.0
    pending_action_buy_price = 0.0
    _log_server(
        "%sgame ended%s: winner=%d reason=%s btc_goal=%.8f winner_btc=%.8f"
        % [ANSI_GREEN, ANSI_RESET, winner_index, reason, btc_goal, winner_btc],
    )


func _apply_player_joined(player_id_value: String, player_index_value: int) -> void:
    connected_player_indexes[player_index_value] = true
    if not player_positions.has(player_index_value):
        player_positions[player_index_value] = -1
    if not player_fiat_balances.has(player_index_value):
        player_fiat_balances[player_index_value] = 0.0
    if not player_bitcoin_balances.has(player_index_value):
        player_bitcoin_balances[player_index_value] = 0.0
    _log_server("player joined: player_id=%s player_index=%d" % [player_id_value, player_index_value])


func _apply_dice_rolled(die_1: int, die_2: int, total: int) -> void:
    _log_server(
        "dice rolled: player=%d, die1=%s%d%s, die2=%s%d%s, total=%s%d%s"
        % [current_player_index, ANSI_YELLOW, die_1, ANSI_RESET, ANSI_YELLOW, die_2, ANSI_RESET, ANSI_YELLOW, total, ANSI_RESET],
    )


func _apply_pawn_moved(from_tile: int, to_tile: int, passed_tiles: Array[int]) -> void:
    player_positions[current_player_index] = to_tile
    _log_server("pawn moved: from=%d, to=%d, passed_tiles=%s" % [from_tile, to_tile, passed_tiles])


func _apply_tile_landed(
        tile_index: int,
        tile_type: String,
        city: String,
        owner_index: int,
        toll_due: float,
        buy_price: float,
        action_required: String,
) -> void:
    pending_action_type = action_required
    pending_action_tile_index = tile_index
    pending_action_owner_index = owner_index
    pending_action_amount = toll_due
    pending_action_buy_price = buy_price
    if city.is_empty():
        _log_server(
            "tile landed: index=%d, tile_type=%s, owner_index=%d, toll_due=%.2f, buy_price=%.2f, action_required=%s" % [
                tile_index,
                tile_type,
                owner_index,
                toll_due,
                buy_price,
                action_required,
            ],
        )
        return
    _log_server(
        "tile landed: index=%d, tile_type=%s, city=%s, owner_index=%d, toll_due=%.2f, buy_price=%.2f, action_required=%s" % [
            tile_index,
            tile_type,
            city,
            owner_index,
            toll_due,
            buy_price,
            action_required,
        ],
    )
    if player_index == current_player_index and action_required == "buy_or_end_turn":
        await _start_buy_or_end_turn_prompt(tile_index, city, buy_price)
        return
    if player_index == current_player_index and action_required == "pay_toll":
        await _start_pay_toll_prompt(tile_index, city, owner_index, toll_due)


func _apply_incident_drawn(tile_index: int, incident_kind: String, card_id: String, card_text: String) -> void:
    var highlighted_card_text: String = "%s%s%s" % [ANSI_YELLOW, card_text, ANSI_RESET]
    _log_server(
        "%sincident drawn%s: tile=%d kind=%s card_id=%s card_text=%s"
        % [ANSI_GREEN, ANSI_RESET, tile_index, incident_kind, card_id, highlighted_card_text],
    )


func _apply_player_balance_changed(player_index_value: int, fiat_delta: float, btc_delta: float, reason: String) -> void:
    connected_player_indexes[player_index_value] = true
    var fiat_balance: float = float(player_fiat_balances.get(player_index_value, 0.0))
    fiat_balance += fiat_delta
    player_fiat_balances[player_index_value] = fiat_balance
    var bitcoin_balance: float = float(player_bitcoin_balances.get(player_index_value, 0.0))
    bitcoin_balance += btc_delta
    player_bitcoin_balances[player_index_value] = bitcoin_balance
    if reason == "inspection_fee_paid":
        player_in_inspection[player_index_value] = false
    if reason == "inspection_voucher_used":
        player_in_inspection[player_index_value] = false
    if reason == "inspection_exit_doubles":
        player_in_inspection[player_index_value] = false
    _log_server(
        "player balance changed: player=%d fiat_delta=%.2f btc_delta=%.8f reason=%s"
        % [player_index_value, fiat_delta, btc_delta, reason],
    )


func _tile_info_from_index(tile_index: int) -> Dictionary:
    var tiles: Array = board_state.get("tiles", [])
    for tile_variant in tiles:
        var tile: Dictionary = tile_variant
        if int(tile.get("index", -1)) == tile_index:
            return tile
    return { }


func _apply_cycle_started(cycle: int, inflation_active: bool) -> void:
    _log_server("cycle started: cycle=%d, inflation_active=%s" % [cycle, inflation_active])


func _apply_incident_type_changed(tile_index: int, incident_kind: String) -> void:
    var tile: Dictionary = _tile_info_from_index(tile_index)
    if not tile.is_empty():
        tile["incident_kind"] = incident_kind
    _log_server("incident type changed: tile=%d incident_kind=%s" % [tile_index, incident_kind])


func _apply_property_acquired(owner_player_index: int, tile_index: int, price: float) -> void:
    connected_player_indexes[owner_player_index] = true
    var owner_fiat_balance: float = float(player_fiat_balances.get(owner_player_index, 0.0))
    owner_fiat_balance -= price
    player_fiat_balances[owner_player_index] = owner_fiat_balance
    var tile: Dictionary = _tile_info_from_index(tile_index)
    if not tile.is_empty():
        tile["owner_index"] = owner_player_index
    pending_action_type = ""
    pending_action_tile_index = -1
    pending_action_owner_index = -1
    pending_action_amount = 0.0
    pending_action_buy_price = 0.0
    _log_server("property acquired: player=%d tile=%d price=%.2f" % [owner_player_index, tile_index, price])


func _apply_miner_batches_added(owner_player_index: int, tile_index: int, count: int) -> void:
    connected_player_indexes[owner_player_index] = true
    var tile: Dictionary = _tile_info_from_index(tile_index)
    if not tile.is_empty():
        var miner_batches: int = int(tile.get("miner_batches", 0))
        tile["miner_batches"] = miner_batches + count
    _log_server("miner batches added: player=%d tile=%d count=%d" % [owner_player_index, tile_index, count])


func _apply_mining_reward(owner_index: int, tile_index: int, miner_batches: int, btc_reward: float, reason: String) -> void:
    connected_player_indexes[owner_index] = true
    _log_server(
        "%smining reward%s: owner=%d tile=%d miner_batches=%d btc_reward=%s%.8f%s reason=%s"
        % [ANSI_GREEN, ANSI_RESET, owner_index, tile_index, miner_batches, ANSI_GREEN, btc_reward, ANSI_RESET, reason],
    )


func _apply_toll_paid(payer_index: int, owner_index: int, amount: float) -> void:
    connected_player_indexes[payer_index] = true
    connected_player_indexes[owner_index] = true
    var payer_fiat_balance: float = float(player_fiat_balances.get(payer_index, 0.0))
    payer_fiat_balance -= amount
    player_fiat_balances[payer_index] = payer_fiat_balance
    var owner_fiat_balance: float = float(player_fiat_balances.get(owner_index, 0.0))
    owner_fiat_balance += amount
    player_fiat_balances[owner_index] = owner_fiat_balance
    pending_action_type = ""
    pending_action_tile_index = -1
    pending_action_owner_index = -1
    pending_action_amount = 0.0
    pending_action_buy_price = 0.0
    _log_server("toll paid: payer=%d owner=%d amount=%.2f" % [payer_index, owner_index, amount])


func _apply_player_sent_to_inspection(player_index_value: int, reason: String) -> void:
    player_in_inspection[player_index_value] = true
    _log_server(
        "%splayer sent to inspection: player=%d reason=%s%s"
        % [ANSI_RED, player_index_value, reason, ANSI_RESET],
    )


func _apply_inspection_voucher_granted(player_index_value: int, amount: int, reason: String) -> void:
    connected_player_indexes[player_index_value] = true
    var free_exits: int = int(player_inspection_free_exits.get(player_index_value, 0))
    free_exits += amount
    player_inspection_free_exits[player_index_value] = free_exits
    _log_server("inspection voucher granted: player=%d amount=%d reason=%s" % [player_index_value, amount, reason])


func _apply_state_snapshot(snapshot: Dictionary) -> void:
    game_id = str(snapshot.get("game_id", game_id))
    current_player_index = int(snapshot.get("current_player_index", current_player_index))
    current_turn_number = int(snapshot.get("turn_number", current_turn_number))
    current_cycle_number = int(snapshot.get("current_cycle", current_cycle_number))
    var pending_action: Dictionary = snapshot.get("pending_action", { })
    pending_action_type = str(pending_action.get("type", ""))
    pending_action_tile_index = int(pending_action.get("tile_index", -1))
    pending_action_owner_index = int(pending_action.get("owner_index", -1))
    pending_action_amount = float(pending_action.get("amount", 0.0))
    pending_action_buy_price = float(pending_action.get("buy_price", 0.0))
    board_state = snapshot.get("board_state", { })
    pending_game_started = false
    match_has_started = bool(snapshot.get("has_started", match_has_started))
    match_has_finished = bool(snapshot.get("has_finished", match_has_finished))
    match_winner_index = int(snapshot.get("winner_index", match_winner_index))
    match_end_reason = str(snapshot.get("end_reason", match_end_reason))
    var board_size: int = int(board_state.get("size", 0))
    var players: Array = snapshot.get("players", [])
    connected_player_indexes.clear()
    player_positions.clear()
    player_fiat_balances.clear()
    player_bitcoin_balances.clear()
    player_in_inspection.clear()
    player_inspection_free_exits.clear()
    player_ready_states.clear()
    for player_variant in players:
        var player_in_snapshot: Dictionary = player_variant
        var player_index_value: int = int(player_in_snapshot.get("player_index", -1))
        if player_index_value < 0:
            continue
        if bool(player_in_snapshot.get("joined", false)):
            connected_player_indexes[player_index_value] = true
        player_positions[player_index_value] = int(player_in_snapshot.get("position", -1))
        player_fiat_balances[player_index_value] = float(player_in_snapshot.get("fiat_balance", 0.0))
        player_bitcoin_balances[player_index_value] = float(player_in_snapshot.get("bitcoin_balance", 0.0))
        player_in_inspection[player_index_value] = bool(player_in_snapshot.get("in_inspection", false))
        player_inspection_free_exits[player_index_value] = int(player_in_snapshot.get("inspection_free_exits", 0))
        player_ready_states[player_index_value] = bool(player_in_snapshot.get("ready", false))
    _log_server(
        "state snapshot: game_id=%s turn=%d cycle=%d current_player=%d players=%d board_size=%d started=%s finished=%s winner=%d end_reason=%s pending_action=%s pending_tile=%d pending_owner=%d pending_amount=%.2f pending_buy_price=%.2f"
        % [
            game_id,
            current_turn_number,
            current_cycle_number,
            current_player_index,
            players.size(),
            board_size,
            match_has_started,
            match_has_finished,
            match_winner_index,
            match_end_reason,
            pending_action_type,
            pending_action_tile_index,
            pending_action_owner_index,
            pending_action_amount,
            pending_action_buy_price,
        ],
    )
    var player_summaries: Array[String] = []
    for player_variant in players:
        var player: Dictionary = player_variant
        player_summaries.append(
            "p%d(id=%s joined=%s ready=%s pos=%d laps=%d fiat=%.2f btc=%.8f inspection=%s free_exits=%d)" % [
                int(player.get("player_index", -1)),
                str(player.get("player_id", "")),
                bool(player.get("joined", false)),
                bool(player.get("ready", false)),
                int(player.get("position", -1)),
                int(player.get("laps", 0)),
                float(player.get("fiat_balance", 0.0)),
                float(player.get("bitcoin_balance", 0.0)),
                bool(player.get("in_inspection", false)),
                int(player.get("inspection_free_exits", 0)),
            ],
        )
    if not player_summaries.is_empty():
        _log_server("state snapshot players: %s" % [", ".join(player_summaries)])


func _build_connected_players_summary() -> String:
    if connected_player_indexes.is_empty():
        return "none"
    var holdings_by_player: Dictionary = { }
    var tiles: Array = board_state.get("tiles", [])
    for tile_variant in tiles:
        var tile: Dictionary = tile_variant
        var owner_index: int = int(tile.get("owner_index", -1))
        if owner_index < 0:
            continue
        if not holdings_by_player.has(owner_index):
            holdings_by_player[owner_index] = { "properties": 0, "miners": 0 }
        var owner_holdings: Dictionary = holdings_by_player[owner_index]
        owner_holdings["properties"] = int(owner_holdings.get("properties", 0)) + 1
        owner_holdings["miners"] = int(owner_holdings.get("miners", 0)) + int(tile.get("miner_batches", 0))
        holdings_by_player[owner_index] = owner_holdings
    var connected_player_indexes_sorted: Array[int] = []
    for player_index_key in connected_player_indexes.keys():
        connected_player_indexes_sorted.append(int(player_index_key))
    connected_player_indexes_sorted.sort()
    var player_summaries: Array[String] = []
    for player_index_value in connected_player_indexes_sorted:
        var player_holdings: Dictionary = holdings_by_player.get(player_index_value, { })
        player_summaries.append(
            "p%d(tile=%d fiat=%s%s%.2f%s btc=%s%.8f%s properties=%d miners=%d)" % [
                player_index_value,
                int(player_positions.get(player_index_value, -1)),
                ANSI_BOLD,
                ANSI_YELLOW,
                float(player_fiat_balances.get(player_index_value, 0.0)),
                ANSI_RESET,
                ANSI_YELLOW,
                float(player_bitcoin_balances.get(player_index_value, 0.0)),
                ANSI_RESET,
                int(player_holdings.get("properties", 0)),
                int(player_holdings.get("miners", 0)),
            ],
        )
    return ", ".join(player_summaries)


func _apply_sync_complete(final_seq: int) -> void:
    var queued_before: int = pending_events.size()
    var dropped_count: int = _drop_stale_pending_events(final_seq)
    var queued_after_drop: int = pending_events.size()
    next_expected_seq = final_seq + 1
    sync_in_progress = false
    var applied_count: int = _flush_events()
    if applied_count == 0:
        await _resume_after_sync_from_snapshot()
    _log_server(
        "sync complete: final_seq=%d next_expected_seq=%d dropped_events=%d queued_before=%d queued_after_drop=%d applied_after_sync=%d"
        % [final_seq, next_expected_seq, dropped_count, queued_before, queued_after_drop, applied_count],
    )


func _apply_action_rejected(reason: String) -> void:
    _log_server("action rejected: reason=%s%s%s%s" % [ANSI_BOLD, ANSI_RED, reason, ANSI_RESET])
    if reason == "insufficient_fiat" and player_index == current_player_index and pending_action_type == "buy_or_end_turn":
        _log_note("buy rejected for insufficient fiat; auto-sending end_turn")
        _request_end_turn()


func _start_turn_prompt() -> void:
    await _start_buy_miner_batch_prompt()
    _log_prompt("press enter to roll dice")
    await _wait_for_enter()
    _request_roll()


func _request_roll() -> void:
    _log_client("roll dice: game_id=%s, player_id=%s" % [game_id, player_id])
    _rpc_to_server("rpc_roll_dice", [game_id, player_id])


func _request_buy_property(tile_index: int) -> void:
    _log_client("buy property: game_id=%s, player_id=%s, tile_index=%d" % [game_id, player_id, tile_index])
    _rpc_to_server("rpc_buy_property", [game_id, player_id, tile_index])


func _request_buy_miner_batch(tile_index: int) -> void:
    _log_client("buy miner batch: game_id=%s, player_id=%s, tile_index=%d" % [game_id, player_id, tile_index])
    _rpc_to_server("rpc_buy_miner_batch", [game_id, player_id, tile_index])


func _request_end_turn() -> void:
    _log_client("end turn: game_id=%s, player_id=%s" % [game_id, player_id])
    _rpc_to_server("rpc_end_turn", [game_id, player_id])


func _request_pay_toll() -> void:
    _log_client(
        "pay toll: game_id=%s, player_id=%s, tile_index=%d, owner_index=%d, amount=%.2f"
        % [game_id, player_id, pending_action_tile_index, pending_action_owner_index, pending_action_amount],
    )
    _rpc_to_server("rpc_pay_toll", [game_id, player_id])


func _request_pay_inspection_fee() -> void:
    _log_client("pay inspection fee: game_id=%s, player_id=%s" % [game_id, player_id])
    _rpc_to_server("rpc_pay_inspection_fee", [game_id, player_id])


func _request_roll_inspection_exit() -> void:
    _log_client("roll inspection exit: game_id=%s, player_id=%s" % [game_id, player_id])
    _rpc_to_server("rpc_roll_inspection_exit", [game_id, player_id])


func _request_use_inspection_voucher() -> void:
    _log_client("use inspection voucher: game_id=%s, player_id=%s" % [game_id, player_id])
    _rpc_to_server("rpc_use_inspection_voucher", [game_id, player_id])


func _request_player_ready() -> void:
    _log_client("player ready: game_id=%s, player_id=%s" % [game_id, player_id])
    _rpc_to_server("rpc_player_ready", [game_id, player_id])


func _rpc_to_server(method: String, args: Array = []) -> void:
    var payload: Array = [1, method]
    payload.append_array(args)
    Callable(self, "rpc_id").callv(payload)


func _drop_stale_pending_events(final_seq: int) -> int:
    var stale_keys: Array = []
    for seq_key in pending_events.keys():
        var seq_value: int = int(seq_key)
        if seq_value <= final_seq:
            stale_keys.append(seq_key)
    for key in stale_keys:
        pending_events.erase(key)
    return stale_keys.size()


func _resume_after_sync_from_snapshot() -> void:
    if not match_has_started:
        if not local_ready_sent and player_index >= 0:
            local_ready_sent = true
            _request_player_ready()
        _log_server("sync resume: waiting for game start")
        return
    if match_has_finished:
        _log_server(
            "sync resume: match already ended winner=%d reason=%s"
            % [match_winner_index, match_end_reason],
        )
        return
    _log_server("%sgame resumed%s: game_id=%s" % [ANSI_GREEN, ANSI_RESET, game_id])
    var board_size: int = int(board_state.get("size", 0))
    if board_size > 0:
        _log_server("board state: size=%d" % board_size)
    var connected_players_summary: String = _build_connected_players_summary()
    _log_server(
        "%sturn started%s: player=%d, turn=%d, cycle=%d, connected_players=[%s]"
        % [ANSI_GREEN, ANSI_RESET, current_player_index, current_turn_number, current_cycle_number, connected_players_summary],
    )
    if player_index != current_player_index:
        _log_server(
            "sync resume: waiting for current player=%d turn=%d"
            % [current_player_index, current_turn_number],
        )
        return
    if pending_action_type == "buy_or_end_turn":
        var city: String = ""
        if pending_action_tile_index >= 0:
            var tile: Dictionary = _tile_info_from_index(pending_action_tile_index)
            city = str(tile.get("city", ""))
        _log_server(
            "sync resume: pending buy_or_end_turn tile=%d city=%s buy_price=%.2f"
            % [pending_action_tile_index, city, pending_action_buy_price],
        )
        await _start_buy_or_end_turn_prompt(pending_action_tile_index, city, pending_action_buy_price)
        return
    if pending_action_type == "pay_toll":
        var pay_toll_city: String = ""
        if pending_action_tile_index >= 0:
            var pay_toll_tile: Dictionary = _tile_info_from_index(pending_action_tile_index)
            pay_toll_city = str(pay_toll_tile.get("city", ""))
        _log_server(
            "sync resume: pending pay_toll tile=%d city=%s owner=%d amount=%.2f"
            % [pending_action_tile_index, pay_toll_city, pending_action_owner_index, pending_action_amount],
        )
        await _start_pay_toll_prompt(
            pending_action_tile_index,
            pay_toll_city,
            pending_action_owner_index,
            pending_action_amount,
        )
        return
    if pending_action_type == "end_turn":
        _log_server("sync resume: pending end_turn")
        _request_end_turn()
        return
    if bool(player_in_inspection.get(player_index, false)):
        _log_server("sync resume: current player in inspection; prompting inspection resolution")
        await _start_inspection_resolution_prompt()
        return
    _log_server("sync resume: prompting roll for current turn=%d" % current_turn_number)
    await _start_turn_prompt()


func _start_buy_or_end_turn_prompt(tile_index: int, city: String, buy_price: float) -> void:
    var label_city: String = city
    var available_fiat: float = float(player_fiat_balances.get(player_index, 0.0))
    if label_city.is_empty():
        label_city = "unknown"
    if buy_price > 0.0:
        _log_prompt(
            "buy property on tile=%d city=%s price=%.2f fiat=%.2f? [y/n]"
            % [tile_index, label_city, buy_price, available_fiat],
        )
    else:
        _log_prompt("buy property on tile=%d city=%s fiat=%.2f? [y/n]" % [tile_index, label_city, available_fiat])
    var buy_property: bool = _wait_for_buy_choice()
    if buy_property:
        _request_buy_property(tile_index)
        return
    _request_end_turn()


func _start_pay_toll_prompt(tile_index: int, city: String, owner_index: int, amount: float) -> void:
    var label_city: String = city
    if label_city.is_empty():
        label_city = "unknown"
    _log_prompt(
        "%spay toll amount%s=%.2f owner=%d tile=%d city=%s [enter]"
        % [ANSI_GREEN, ANSI_RESET, amount, owner_index, tile_index, label_city],
    )
    await _wait_for_enter()
    _request_pay_toll()


func _start_buy_miner_batch_prompt() -> void:
    var miner_price: float = EconomyV0.MINER_BATCH_PRICE
    var available_fiat: float = float(player_fiat_balances.get(player_index, 0.0))
    if available_fiat < miner_price:
        _log_note(
            "skipping miner prompt: fiat=%.2f below miner price=%.2f"
            % [available_fiat, miner_price],
        )
        return
    var owned_tile_indexes: Array[int] = []
    var tiles: Array = board_state.get("tiles", [])
    for tile_variant in tiles:
        var tile: Dictionary = tile_variant
        var tile_type: String = str(tile.get("tile_type", ""))
        if tile_type != "property" and tile_type != "special_property":
            continue
        if int(tile.get("owner_index", -1)) != player_index:
            continue
        var miner_batches: int = int(tile.get("miner_batches", 0))
        if miner_batches >= EconomyV0.MAX_MINER_BATCHES_PER_PROPERTY:
            continue
        owned_tile_indexes.append(int(tile.get("index", -1)))
    if owned_tile_indexes.is_empty():
        _log_note("skipping miner prompt: no owned property with available miner slots")
        return
    owned_tile_indexes.sort()
    var tile_choices: PackedStringArray = []
    for tile_index in owned_tile_indexes:
        tile_choices.append(str(tile_index))
    _log_prompt(
        "buy miner batch price=%.2f choose owned tile index [%s] or press enter to skip"
        % [miner_price, ", ".join(tile_choices)],
    )
    var selected_tile: int = _wait_for_tile_choice(owned_tile_indexes)
    if selected_tile < 0:
        return
    _request_buy_miner_batch(selected_tile)


func _start_inspection_resolution_prompt() -> void:
    var fee: float = EconomyV0.INSPECTION_FEE
    while true:
        var free_exits: int = int(player_inspection_free_exits.get(player_index, 0))
        if free_exits > 0:
            _log_prompt("in inspection: use free exit voucher=%d? [y/n]" % [free_exits])
            var use_voucher: bool = _wait_for_buy_choice()
            if use_voucher:
                player_inspection_free_exits[player_index] = free_exits - 1
                player_in_inspection[player_index] = false
                _request_use_inspection_voucher()
                await _start_turn_prompt()
                return
        _log_prompt("in inspection: try doubles roll? [y/n]")
        var roll_exit: bool = _wait_for_buy_choice()
        if roll_exit:
            _request_roll_inspection_exit()
            return
        var available_fiat: float = float(player_fiat_balances.get(player_index, 0.0))
        if available_fiat < fee:
            _log_note(
                "cannot pay inspection fee: fiat=%.2f required=%.2f; choose doubles roll to continue"
                % [available_fiat, fee],
            )
            continue
        _log_prompt("in inspection: pay fee amount=%.2f [enter]" % [fee])
        await _wait_for_enter()
        _request_pay_inspection_fee()
        await _start_turn_prompt()
        return


func _wait_for_buy_choice() -> bool:
    if not OS.has_method("read_string_from_stdin"):
        _log_note("stdin not available; defaulting to end turn")
        return false
    var input_text: String = OS.read_string_from_stdin().strip_edges().to_lower()
    if input_text == "y" or input_text == "yes":
        return true
    if input_text == "n" or input_text == "no" or input_text.is_empty():
        return false
    _log_note("unknown response '%s'; defaulting to end turn" % input_text)
    return false


func _wait_for_enter() -> void:
    if OS.has_method("read_string_from_stdin"):
        OS.read_string_from_stdin()
        return
    _log_note("stdin not available; continuing")


func _wait_for_tile_choice(valid_tile_indexes: Array[int]) -> int:
    if not OS.has_method("read_string_from_stdin"):
        return -1
    var input_text: String = OS.read_string_from_stdin().strip_edges().to_lower()
    if input_text.is_empty():
        return -1
    if not input_text.is_valid_int():
        _log_note("invalid tile index '%s'; skipping miner purchase" % input_text)
        return -1
    var tile_index: int = int(input_text)
    if not valid_tile_indexes.has(tile_index):
        _log_note("tile index %d is not a valid owned property; skipping miner purchase" % tile_index)
        return -1
    return tile_index


func _log_server(message: String) -> void:
    print("server[p=%d id=%s g=%s]: %s" % [player_index, player_id, game_id, message])


func _log_client(message: String) -> void:
    print("client[p=%d id=%s g=%s]: %s" % [player_index, player_id, game_id, message])


func _log_prompt(message: String) -> void:
    print("prompt[p=%d id=%s g=%s]: %s" % [player_index, player_id, game_id, message])


func _log_note(message: String) -> void:
    print("note[p=%d id=%s g=%s]: %s" % [player_index, player_id, game_id, message])
