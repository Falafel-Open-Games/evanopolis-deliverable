extends "res://scripts/app/headless_rpc_client.gd"
class_name SessionCheck

## Session admission controller for the graphical client.
##
## This module sits between `AppBoot` and the first player-facing session UI.
## It does not render the waiting room or gameplay. Its job is to take a valid
## launch payload, perform the minimum server-backed handshake, and publish:
## - a small readable connection state for boot / connect / failure phases
## - a waiting-room state once auth, join, and sync have completed
##
## Current responsibilities:
## - wait for `AppBoot` to publish a `LaunchPayload`
## - connect to the game server transport
## - send `rpc_auth(token)`
## - send `rpc_join(game_id, player_id)` after auth success
## - request `rpc_sync_request(...)` after join success
## - install the pre-match parts of the authoritative sync snapshot
## - expose waiting-room-ready seat and ready-state data
##
## This controller is intentionally narrow. Later stages such as gameplay
## should consume the successful connected state it produces, rather than
## expanding this file into a general-purpose match-state module.

const StatusCardState = preload("res://scripts/app/models/status_view_state.gd")
const GameEconomyConfigModel = preload("res://scripts/app/models/game_economy_config.gd")
const GamePlayerHudStateModel = preload("res://scripts/app/models/game_player_hud_state.gd")
const LaunchPayloadModel = preload("res://scripts/app/models/launch_payload.gd")
const WaitingRoomStateModel = preload("res://scripts/app/models/waiting_room_state.gd")
const WaitingRoomSlotModel = preload("res://scripts/app/models/waiting_room_slot.gd")
const SessionTransport = preload("res://scripts/app/session_transport.gd")

const DEFAULT_IDENTITY_ICON_ID: int = 0
const DEFAULT_IDENTITY_COLOR_ID: int = 0

signal session_state_changed(state: StatusCardState)
signal waiting_room_state_changed(state: WaitingRoomStateModel)
signal gameplay_turn_state_changed(turn_state: Dictionary)
signal gameplay_player_states_changed(states: Array)
signal gameplay_event_log_changed(messages: Array)
signal gameplay_pawn_positions_changed(tile_positions_by_player_index: Dictionary)
signal gameplay_tile_ownership_changed(tile_owner_indices_by_tile_index: Dictionary)

enum SessionPhase {
    WAITING_FOR_LAUNCH,
    CONNECTING,
    RETRYING,
    AUTHENTICATING,
    JOINING,
    SYNCING,
    READY,
    GAME_STARTED,
    FAILED,
}

enum GameplayConnectionPhase {
    CONNECTED,
    CONNECTION_LOST,
    RECONNECTING,
    RESYNCING,
    FAILED,
}

const MAX_CONNECT_ATTEMPTS: int = 2
const GAMEPLAY_RECONNECT_DELAYS_SECONDS: Array[float] = [1.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 15.0, 15.0, 15.0]
const RETRY_DELAY_SECONDS: float = 0.75
const DEBUG_GAMEPLAY_ARGUMENT: String = "--debug"
const RECONNECT_EVENT_LOG_KEY_PREFIX: String = "reconnect_status_"

@export var boot_node: AppBoot

var _launch_payload: LaunchPayloadModel
var _session_state: StatusCardState = StatusCardState.new(
    "Waiting for launch data",
    "The session checker is idle until AppBoot publishes a launch payload.",
    "This is the first server-backed step after the wrapper handoff."
)
var _phase: SessionPhase
var _gameplay_connection_phase: GameplayConnectionPhase = GameplayConnectionPhase.CONNECTED
var _current_player_id: String
var _local_player_index: int
var _has_auth_ok: bool
var _has_join_accepted: bool
var _has_snapshot: bool
var _connect_attempts: int
var _retry_timer: Timer
var _gameplay_reconnect_timer: Timer
var _waiting_room_reconnect_timer: Timer
var _session_transport: SessionTransport
var _room_game_id: String
var _room_capacity: int
var _known_player_ids: Dictionary = { }
var _joined_players: Dictionary = { }
var _known_player_display_names: Dictionary = { }
var _known_player_icon_ids: Dictionary = { }
var _known_player_color_ids: Dictionary = { }
var _player_fiat_balances: Dictionary = { }
var _player_bitcoin_balances: Dictionary = { }
var _player_sell_percents: Dictionary = { }
var _player_last_allocation_changed_turns: Dictionary = { }
var _player_landing_sequences: Dictionary = { }
var _active_players: Dictionary = { }
var _ready_players: Array = []
var _current_turn_number: int = 1
var _current_turn_player_index: int = 0
var _waiting_room_state: WaitingRoomStateModel
var _waiting_room_note: String = ""
var _ready_request_pending: bool = false
var _identity_request_pending: bool = false
var _match_has_started: bool = false
var _match_has_finished: bool = false
var _winner_index: int = -1
var _gameplay_event_log_messages: Array = []
var _board_state: Dictionary = { }
var _player_tile_positions: Dictionary = { }
var _next_landing_sequence: int = 1
var _pending_action_type: String = ""
var _pending_action_tile_index: int = -1
var _pending_property_action: Dictionary = { }
var _has_rolled_current_turn: bool = false
var _last_die_1: int = 6
var _last_die_2: int = 6
var _roll_request_pending: bool = false
var _buy_property_request_pending: bool = false
var _pay_toll_request_pending: bool = false
var _end_turn_request_pending: bool = false
var _energy_allocation_request_pending: bool = false
var _gameplay_reconnect_attempts: int = 0
var _active_reconnect_event_log_key: String = ""
var _reconnect_event_log_sequence: int = 0
var _waiting_room_reconnect_attempts: int = 0
var _waiting_room_reconnect_active: bool = false

func _ready() -> void:
    assert(boot_node)
    assert(boot_node.has_signal("launch_payload_received"))
    boot_node.connect("launch_payload_received", _on_launch_payload_received)

    _session_transport = SessionTransport.new()
    add_child(_session_transport)
    _session_transport.connected.connect(_on_connected_to_server)
    _session_transport.connection_failed.connect(_on_connection_failed)
    _session_transport.server_disconnected.connect(_on_server_disconnected)

    _update_state(
        SessionPhase.WAITING_FOR_LAUNCH,
        "Waiting for launch data",
        "The session checker is idle until AppBoot publishes a launch payload.",
        "This is the first server-backed step after the wrapper handoff."
    )

func get_session_state() -> StatusCardState:
    return _session_state.clone()

func get_waiting_room_state() -> WaitingRoomStateModel:
    assert(_waiting_room_state)
    return _waiting_room_state.clone()

func get_gameplay_turn_state() -> Dictionary:
    var current_player_name: String = _player_display_name(_current_turn_player_index)
    if current_player_name.is_empty():
        current_player_name = "Player"
    var local_sell_percent: int = _player_sell_percent(_local_player_index)
    var local_owned_economy_totals: Dictionary = _owned_tile_economy_totals(_local_player_index)
    var property_action: Dictionary = _pending_property_action.duplicate(true)
    if property_action.is_empty():
        property_action = _build_property_action_state_from_current_pending_action()
    if not property_action.is_empty():
        property_action = _refresh_property_action_state(property_action)
        property_action["can_buy_property"] = can_request_buy_property(int(property_action.get("tile_index", -1)))
        property_action["can_afford_buy_property"] = _can_afford_buy_property(float(property_action.get("buy_price", 0.0)))
        property_action["can_pay_toll"] = can_request_pay_toll()
        property_action["can_afford_pay_toll"] = _can_afford_pay_toll(float(property_action.get("toll_due", 0.0)))
        property_action["show_bitcoin_toll_price"] = _should_show_bitcoin_toll_price(float(property_action.get("toll_due", 0.0)))
    return {
        "turn_number": _current_turn_number,
        "current_player_index": _current_turn_player_index,
        "current_player_name": current_player_name,
        "is_local_turn": _current_turn_player_index == _local_player_index,
        "is_local_winner": _winner_index >= 0 and _winner_index == _local_player_index,
        "connection_state": _gameplay_connection_phase_name(),
        "connection_interactive": _is_gameplay_connection_interactive(),
        "die_1": _last_die_1,
        "die_2": _last_die_2,
        "can_roll_dice": can_request_roll_dice(),
        "can_buy_property": can_request_buy_property(),
        "can_end_turn": can_request_end_turn(),
        "pending_action_type": _pending_action_type,
        "pending_action_tile_index": _pending_action_tile_index,
        "sell_percent": local_sell_percent,
        "mine_percent": 100 - local_sell_percent,
        "can_set_energy_allocation": can_request_energy_allocation(),
        "energy_allocation_request_pending": _energy_allocation_request_pending,
        "sell_100_fiat_total": float(local_owned_economy_totals.get("sell_100_fiat", 0.0)),
        "mine_100_btc_total": float(local_owned_economy_totals.get("mine_100_btc", 0.0)),
        "property_action": property_action,
    }

func get_gameplay_player_states() -> Array:
    var states: Array = []
    var joined_player_indices: Array = _joined_players.keys()
    joined_player_indices.sort()
    for player_index_variant in joined_player_indices:
        var player_index: int = int(player_index_variant)
        if not bool(_joined_players.get(player_index, false)):
            continue
        states.append(
            GamePlayerHudStateModel.new(
                player_index,
                _gameplay_display_name(player_index),
                player_index == _local_player_index,
                _player_icon_id(player_index),
                _player_color_id(player_index),
                _player_fiat_balance(player_index),
                _player_energy_balance(player_index),
                _player_bitcoin_balance(player_index),
                _player_landing_sequence(player_index),
                _is_player_active(player_index)
            )
        )
    return _clone_gameplay_player_states(states)

func get_gameplay_event_log_messages() -> Array:
    return _gameplay_event_log_messages.duplicate()

func get_gameplay_pawn_positions() -> Dictionary:
    return _player_tile_positions.duplicate()

func get_gameplay_tile_owner_indices() -> Dictionary:
    return _tile_owner_indices_by_tile_index()

func is_waiting_for_launch() -> bool:
    return _phase == SessionPhase.WAITING_FOR_LAUNCH

func is_waiting_room_active() -> bool:
    return _phase == SessionPhase.READY

func is_game_started() -> bool:
    return _phase == SessionPhase.GAME_STARTED

func has_waiting_room_state() -> bool:
    return _waiting_room_state != null

func can_request_player_ready() -> bool:
    if _phase != SessionPhase.READY:
        return false
    if not _is_waiting_room_connection_interactive():
        return false
    if _local_player_index < 0:
        return false
    if _ready_request_pending:
        return false
    return not _is_player_ready(_local_player_index)

func can_request_player_identity() -> bool:
    if _phase != SessionPhase.READY:
        return false
    if not _is_waiting_room_connection_interactive():
        return false
    if _local_player_index < 0:
        return false
    return not _identity_request_pending

func can_request_roll_dice() -> bool:
    if _phase != SessionPhase.GAME_STARTED:
        return false
    if not _is_gameplay_connection_interactive():
        return false
    if _launch_payload == null:
        return false
    if _current_player_id.is_empty():
        return false
    if _local_player_index < 0:
        return false
    if _match_has_finished:
        return false
    if _roll_request_pending:
        return false
    if _has_rolled_current_turn:
        return false
    if _current_turn_player_index != _local_player_index:
        return false
    return _pending_action_type.is_empty()

func can_request_end_turn() -> bool:
    if _phase != SessionPhase.GAME_STARTED:
        return false
    if not _is_gameplay_connection_interactive():
        return false
    if _launch_payload == null:
        return false
    if _current_player_id.is_empty():
        return false
    if _local_player_index < 0:
        return false
    if _match_has_finished:
        return false
    if _end_turn_request_pending:
        return false
    if _buy_property_request_pending:
        return false
    if _pay_toll_request_pending:
        return false
    if _current_turn_player_index != _local_player_index:
        return false
    if can_request_roll_dice():
        return false
    if _pending_action_type == "pay_toll":
        return not _can_afford_pay_toll(_pending_toll_due())
    if _pending_action_type == "resolve_incident":
        return false
    return true

func can_request_buy_property(tile_index: int = -1) -> bool:
    if _phase != SessionPhase.GAME_STARTED:
        return false
    if not _is_gameplay_connection_interactive():
        return false
    if _launch_payload == null:
        return false
    if _current_player_id.is_empty():
        return false
    if _local_player_index < 0:
        return false
    if _match_has_finished:
        return false
    if _buy_property_request_pending:
        return false
    if _pay_toll_request_pending:
        return false
    if _current_turn_player_index != _local_player_index:
        return false
    if _pending_action_type != "buy_or_end_turn":
        return false
    if _pending_action_tile_index < 0:
        return false
    return tile_index < 0 or tile_index == _pending_action_tile_index

func can_request_pay_toll() -> bool:
    if _phase != SessionPhase.GAME_STARTED:
        return false
    if not _is_gameplay_connection_interactive():
        return false
    if _launch_payload == null:
        return false
    if _current_player_id.is_empty():
        return false
    if _local_player_index < 0:
        return false
    if _match_has_finished:
        return false
    if _buy_property_request_pending:
        return false
    if _pay_toll_request_pending:
        return false
    if _end_turn_request_pending:
        return false
    if _current_turn_player_index != _local_player_index:
        return false
    if _pending_action_type != "pay_toll":
        return false
    return _pending_action_tile_index >= 0

func can_request_energy_allocation() -> bool:
    if _phase != SessionPhase.GAME_STARTED:
        return false
    if not _is_gameplay_connection_interactive():
        return false
    if _launch_payload == null:
        return false
    if _current_player_id.is_empty():
        return false
    if _local_player_index < 0:
        return false
    if _match_has_finished:
        return false
    if _energy_allocation_request_pending:
        return false
    if not _is_player_active(_local_player_index):
        return false
    return _player_last_allocation_changed_turn(_local_player_index) != _current_turn_number

func _can_afford_buy_property(buy_price: float) -> bool:
    if _local_player_index < 0:
        return false
    return _player_fiat_balance(_local_player_index) >= buy_price

func _can_afford_pay_toll(toll_due: float) -> bool:
    if _local_player_index < 0:
        return false
    return (
        _player_fiat_balance(_local_player_index) >= toll_due
        or _player_bitcoin_balance(_local_player_index) >= 1.0
    )

func _pending_toll_due() -> float:
    if not _pending_property_action.is_empty():
        return float(_pending_property_action.get("toll_due", 0.0))
    if _pending_action_type == "pay_toll":
        var tile: Dictionary = _tile_info_from_board_state(_pending_action_tile_index)
        return float(tile.get("toll", 0.0))
    return 0.0

func _should_show_bitcoin_toll_price(toll_due: float) -> bool:
    if _local_player_index < 0:
        return false
    return (
        _player_fiat_balance(_local_player_index) < toll_due
        and _player_bitcoin_balance(_local_player_index) >= 1.0
    )

func request_player_ready() -> void:
    assert(_launch_payload)
    assert(_current_player_id != "")
    assert(_local_player_index >= 0)
    if not _is_waiting_room_connection_interactive():
        _begin_waiting_room_reconnect()
        return
    if not can_request_player_ready():
        return

    _ready_request_pending = true
    _waiting_room_note = "Sending ready signal to the game server."
    _emit_waiting_room_state()
    rpc_id(1, "rpc_player_ready", _launch_payload._game_id, _current_player_id)

func request_roll_dice() -> void:
    assert(_launch_payload)
    assert(not _current_player_id.is_empty())
    assert(_local_player_index >= 0)
    if not can_request_roll_dice():
        _emit_gameplay_turn_state()
        return

    _roll_request_pending = true
    _emit_gameplay_turn_state()
    rpc_id(1, "rpc_roll_dice", _launch_payload._game_id, _current_player_id)

func request_end_turn() -> void:
    assert(_launch_payload)
    assert(not _current_player_id.is_empty())
    assert(_local_player_index >= 0)
    if not can_request_end_turn():
        _emit_gameplay_turn_state()
        return

    _end_turn_request_pending = true
    _emit_gameplay_turn_state()
    rpc_id(1, "rpc_end_turn", _launch_payload._game_id, _current_player_id)

func request_buy_property(tile_index: int) -> void:
    assert(_launch_payload)
    assert(not _current_player_id.is_empty())
    assert(_local_player_index >= 0)
    if not can_request_buy_property(tile_index):
        _emit_gameplay_turn_state()
        return

    _buy_property_request_pending = true
    _emit_gameplay_turn_state()
    rpc_id(1, "rpc_buy_property", _launch_payload._game_id, _current_player_id, tile_index)

func request_pay_toll() -> void:
    assert(_launch_payload)
    assert(not _current_player_id.is_empty())
    assert(_local_player_index >= 0)
    if not can_request_pay_toll():
        _emit_gameplay_turn_state()
        return

    _pay_toll_request_pending = true
    _emit_gameplay_turn_state()
    rpc_id(1, "rpc_pay_toll", _launch_payload._game_id, _current_player_id)

func request_energy_allocation(sell_percent: int) -> void:
    assert(_launch_payload)
    assert(not _current_player_id.is_empty())
    assert(_local_player_index >= 0)
    var normalized_sell_percent: int = clampi(sell_percent, 0, 100)
    if normalized_sell_percent == _player_sell_percent(_local_player_index):
        _emit_gameplay_turn_state()
        return
    if not can_request_energy_allocation():
        _emit_gameplay_turn_state()
        return

    _energy_allocation_request_pending = true
    _emit_gameplay_turn_state()
    rpc_id(1, "rpc_set_energy_allocation", _launch_payload._game_id, _current_player_id, normalized_sell_percent)

func request_player_identity(display_name: String, icon_id: int, color_id: int) -> void:
    assert(_launch_payload)
    assert(_current_player_id != "")
    assert(_local_player_index >= 0)
    if not _is_waiting_room_connection_interactive():
        _begin_waiting_room_reconnect()
        return
    if not can_request_player_identity():
        return

    var normalized_display_name: String = display_name.strip_edges()
    if normalized_display_name.is_empty():
        _waiting_room_note = "Display name is required before saving identity."
        _emit_waiting_room_state()
        return

    _identity_request_pending = true
    _waiting_room_note = "Sending identity update to the game server."
    _emit_waiting_room_state()
    rpc_id(
        1,
        "rpc_set_player_identity",
        _launch_payload._game_id,
        _current_player_id,
        normalized_display_name,
        icon_id,
        color_id
    )

func _on_launch_payload_received(payload: LaunchPayloadModel) -> void:
    if _phase != SessionPhase.WAITING_FOR_LAUNCH and _phase != SessionPhase.FAILED:
        return

    _launch_payload = payload
    _gameplay_connection_phase = GameplayConnectionPhase.CONNECTED
    _current_player_id = ""
    _local_player_index = -1
    _has_auth_ok = false
    _has_join_accepted = false
    _has_snapshot = false
    _connect_attempts = 0
    _room_game_id = payload._game_id
    _room_capacity = 0
    _known_player_ids.clear()
    _joined_players.clear()
    _known_player_display_names.clear()
    _known_player_icon_ids.clear()
    _known_player_color_ids.clear()
    _player_fiat_balances.clear()
    _player_bitcoin_balances.clear()
    _player_sell_percents.clear()
    _player_last_allocation_changed_turns.clear()
    _player_landing_sequences.clear()
    _ready_players.clear()
    _current_turn_number = 1
    _current_turn_player_index = 0
    _waiting_room_state = null
    _waiting_room_note = ""
    _ready_request_pending = false
    _identity_request_pending = false
    _match_has_started = false
    _match_has_finished = false
    _winner_index = -1
    _gameplay_event_log_messages.clear()
    _board_state.clear()
    _player_tile_positions.clear()
    _next_landing_sequence = 1
    _pending_action_type = ""
    _pending_action_tile_index = -1
    _pending_property_action.clear()
    _has_rolled_current_turn = false
    _roll_request_pending = false
    _buy_property_request_pending = false
    _pay_toll_request_pending = false
    _end_turn_request_pending = false
    _energy_allocation_request_pending = false
    _gameplay_reconnect_attempts = 0
    _active_reconnect_event_log_key = ""
    _reconnect_event_log_sequence = 0
    _waiting_room_reconnect_attempts = 0
    _waiting_room_reconnect_active = false
    _connect_to_server()

func _connect_to_server() -> void:
    assert(_launch_payload)
    _connect_attempts += 1
    _update_state(
        SessionPhase.CONNECTING,
        "Connecting to game server",
        "Opening a multiplayer connection to %s." % _launch_payload._game_server_url,
        "The client will authenticate with `rpc_auth(...)` once the transport is up."
    )
    _session_transport.connect_to_server(_launch_payload._game_server_url)

func _on_connected_to_server() -> void:
    assert(_launch_payload)
    if _waiting_room_reconnect_active:
        _has_auth_ok = false
        _has_join_accepted = false
        _has_snapshot = false
        rpc_id(1, "rpc_auth", _launch_payload._token)
        return

    if _is_gameplay_reconnect_in_progress():
        _has_auth_ok = false
        _has_join_accepted = false
        _has_snapshot = false
        _set_gameplay_connection_phase(GameplayConnectionPhase.RECONNECTING)
        rpc_id(1, "rpc_auth", _launch_payload._token)
        return

    _update_state(
        SessionPhase.AUTHENTICATING,
        "Authenticating session",
        "The client is sending `rpc_auth(...)` with the launch token.",
        "The game server will verify the token with the auth service before join."
    )
    rpc_id(1, "rpc_auth", _launch_payload._token)

func _on_connection_failed() -> void:
    if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
        if _waiting_room_reconnect_attempts <= GAMEPLAY_RECONNECT_DELAYS_SECONDS.size():
            _schedule_waiting_room_reconnect_retry()
            return
        _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
        return
    if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
        if _gameplay_reconnect_attempts <= GAMEPLAY_RECONNECT_DELAYS_SECONDS.size():
            _schedule_gameplay_reconnect_retry()
            return
        _fail_gameplay_reconnect("Reconnect failed. Refresh to try again.")
        return
    if _try_schedule_retry("The multiplayer connection to the game server failed."):
        return
    _fail_session("The multiplayer connection to the game server failed.")

func _on_server_disconnected() -> void:
    if _phase == SessionPhase.READY:
        _begin_waiting_room_reconnect()
        return
    if _phase == SessionPhase.GAME_STARTED:
        _begin_gameplay_reconnect()
        return
    if _phase == SessionPhase.READY or _phase == SessionPhase.GAME_STARTED:
        return
    if _try_schedule_retry("The game server disconnected during session setup."):
        return
    _fail_session("The game server disconnected during session setup.")

@rpc("authority")
func rpc_auth_ok(player_id: String, _exp: int) -> void:
    assert(_launch_payload)
    if player_id.strip_edges() == "":
        if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
            _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
            return
        if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
            _fail_gameplay_reconnect("Reconnect failed because the server returned an empty player id.")
            return
        _fail_session("The game server returned an empty player id.")
        return

    if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
        if not _current_player_id.is_empty() and player_id != _current_player_id:
            _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
            return
        _current_player_id = player_id
        _has_auth_ok = true
        rpc_id(1, "rpc_join", _launch_payload._game_id, player_id)
        return

    if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
        if not _current_player_id.is_empty() and player_id != _current_player_id:
            _fail_gameplay_reconnect("Reconnect failed because the server authenticated a different player id.")
            return
        _current_player_id = player_id
        _has_auth_ok = true
        rpc_id(1, "rpc_join", _launch_payload._game_id, player_id)
        return

    _current_player_id = player_id
    _has_auth_ok = true
    _update_state(
        SessionPhase.JOINING,
        "Joining match session",
        "Auth succeeded as `%s`. The client is now sending `rpc_join(...)` for room `%s`." % [player_id, _launch_payload._game_id],
        "The server remains authoritative for room admission and match state."
    )
    rpc_id(1, "rpc_join", _launch_payload._game_id, player_id)

@rpc("authority")
func rpc_auth_error(reason: String) -> void:
    if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
        _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
        return
    if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
        _fail_gameplay_reconnect("Reconnect failed during authentication: %s" % reason)
        return
    _fail_session("Authentication failed: %s" % reason)

@rpc("authority")
func rpc_join_accepted(_seq: int, player_id: String, player_index: int, last_seq: int) -> void:
    assert(_launch_payload)
    if not _has_auth_ok:
        if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
            _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
            return
        if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
            _fail_gameplay_reconnect("Reconnect failed because join success arrived before auth completed.")
            return
        _fail_session("Received join success before auth completed.")
        return
    if player_id != _current_player_id:
        if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
            _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
            return
        if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
            _fail_gameplay_reconnect("Reconnect failed because the server accepted a different player id.")
            return
        _fail_session("The server accepted a different player id than the one that authenticated.")
        return

    if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
        _has_join_accepted = true
        _local_player_index = player_index
        _known_player_ids[player_index] = player_id
        _waiting_room_note = "Reconnected. Syncing lobby."
        _emit_waiting_room_state()
        rpc_id(1, "rpc_sync_request", _launch_payload._game_id, player_id, last_seq)
        return

    if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
        _has_join_accepted = true
        _local_player_index = player_index
        _known_player_ids[player_index] = player_id
        _set_gameplay_connection_phase(GameplayConnectionPhase.RESYNCING)
        _upsert_gameplay_event_log_message(
            _current_reconnect_event_log_key(),
            "Reconnected. Syncing game state.",
            -1,
            "🔄"
        )
        rpc_id(1, "rpc_sync_request", _launch_payload._game_id, player_id, last_seq)
        return

    _has_join_accepted = true
    _local_player_index = player_index
    _known_player_ids[player_index] = player_id
    _update_state(
        SessionPhase.SYNCING,
        "Syncing session state",
        "Join succeeded. The client is requesting authoritative state starting from sequence %d." % last_seq,
        "This keeps the Godot client aligned with the existing reconnect and sync contract."
    )
    rpc_id(1, "rpc_sync_request", _launch_payload._game_id, player_id, last_seq)

@rpc("authority")
func rpc_action_rejected(_seq: int, reason: String) -> void:
    if _phase == SessionPhase.READY:
        if _identity_request_pending:
            _identity_request_pending = false
            _waiting_room_note = "Identity update rejected: %s" % reason
            _emit_waiting_room_state()
            return
        _ready_request_pending = false
        _waiting_room_note = "Ready action rejected: %s" % reason
        _emit_waiting_room_state()
        return
    if _phase == SessionPhase.GAME_STARTED:
        _roll_request_pending = false
        _buy_property_request_pending = false
        _pay_toll_request_pending = false
        _end_turn_request_pending = false
        _energy_allocation_request_pending = false
        _append_gameplay_event_log_message("Action rejected: %s" % reason, _current_turn_player_index)
        _emit_gameplay_turn_state()
        return
    _fail_session("The game server rejected the session: %s" % reason)

@rpc("authority")
func rpc_state_snapshot(_seq: int, snapshot: Dictionary) -> void:
    var is_gameplay_resync: bool = _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress()
    _has_snapshot = true
    _current_turn_number = int(snapshot.get("turn_number", _current_turn_number))
    _current_turn_player_index = int(snapshot.get("current_player_index", _current_turn_player_index))
    _has_rolled_current_turn = bool(snapshot.get("has_rolled_current_turn", false))
    _last_die_1 = int(snapshot.get("last_die_1", 6))
    _last_die_2 = int(snapshot.get("last_die_2", 6))
    _buy_property_request_pending = false
    _pay_toll_request_pending = false
    _pending_action_type = ""
    _pending_action_tile_index = -1
    _pending_property_action.clear()
    var pending_action: Dictionary = snapshot.get("pending_action", { })
    if not pending_action.is_empty():
        _pending_action_type = str(pending_action.get("type", ""))
        _pending_action_tile_index = int(pending_action.get("tile_index", -1))
    _board_state = snapshot.get("board_state", { }).duplicate(true)
    if not pending_action.is_empty():
        _pending_property_action = _build_property_action_state_from_pending_action(pending_action)
    _apply_player_positions_snapshot(snapshot)
    _apply_waiting_room_snapshot(snapshot)
    if not is_gameplay_resync:
        _gameplay_event_log_messages.clear()
        _append_gameplay_event_log_message("Game state synchronized", -1, "🔄")
    else:
        _upsert_gameplay_event_log_message(
            _current_reconnect_event_log_key(),
            "Game state synchronized",
            -1,
            "🔄"
        )
    if _match_has_finished and int(snapshot.get("winner_index", -1)) >= 0:
        _append_gameplay_snapshot_winner_message(
            int(snapshot.get("winner_index", -1)),
            str(snapshot.get("end_reason", ""))
        )
    _emit_gameplay_turn_state()
    _emit_gameplay_pawn_positions()
    _emit_gameplay_player_states()
    _emit_gameplay_tile_ownership()
    _debug_print_authoritative_gameplay_state("state_snapshot")

@rpc("authority")
func rpc_sync_complete(_seq: int, _final_seq: int) -> void:
    if not _has_join_accepted:
        if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
            _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
            return
        if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
            _fail_gameplay_reconnect("Reconnect failed because sync completion arrived before join acceptance.")
            return
        _fail_session("Received sync completion before join acceptance.")
        return
    if not _has_snapshot:
        if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
            _fail_waiting_room_reconnect("Reconnect failed. Refresh to try again.")
            return
        if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
            _fail_gameplay_reconnect("Reconnect failed because sync completion arrived before state snapshot.")
            return
        _fail_session("Received sync completion before state snapshot.")
        return

    if _phase == SessionPhase.READY and _waiting_room_reconnect_active:
        _waiting_room_reconnect_attempts = 0
        _waiting_room_reconnect_active = false
        _waiting_room_note = "Lobby reconnected."
        _emit_waiting_room_state()
        return

    if _phase == SessionPhase.GAME_STARTED and _is_gameplay_reconnect_in_progress():
        _gameplay_reconnect_attempts = 0
        _set_gameplay_connection_phase(GameplayConnectionPhase.CONNECTED)
        _upsert_gameplay_event_log_message(
            _current_reconnect_event_log_key(),
            "Gameplay resumed",
            -1,
            "🔄"
        )
        _emit_gameplay_turn_state()
        return

    if _match_has_started:
        _update_state(
            SessionPhase.GAME_STARTED,
            "Match resumed",
            "The server snapshot shows this match has already started, so the client is skipping the waiting room.",
            "Reconnect and restart flows now hand back directly to gameplay after sync."
        )
        return

    _update_state(
        SessionPhase.READY,
        "Waiting room ready",
        "The client finished auth, join, and sync and can now stay in the pre-match waiting room.",
        "The room UI is now driven by the authoritative snapshot plus later ready and join broadcasts."
    )
    _emit_waiting_room_state()

@rpc("authority")
func rpc_player_joined(_seq: int, player_id: String, player_index: int) -> void:
    _known_player_ids[player_index] = player_id
    _joined_players[player_index] = true
    if _phase == SessionPhase.READY:
        _emit_waiting_room_state()
    _emit_gameplay_player_states()

@rpc("authority")
func rpc_player_ready_state(
    _seq: int,
    player_index: int,
    is_ready: bool,
    _ready_count: int,
    total_players: int
) -> void:
    _room_capacity = max(_room_capacity, total_players)
    _set_player_ready(player_index, is_ready)
    if player_index == _local_player_index:
        _ready_request_pending = false
    _waiting_room_note = ""
    if _phase == SessionPhase.READY:
        _emit_waiting_room_state()

@rpc("authority")
func rpc_player_identity_changed(
    _seq: int,
    player_index: int,
    display_name: String,
    icon_id: int,
    color_id: int
) -> void:
    _known_player_display_names[player_index] = display_name
    _known_player_icon_ids[player_index] = icon_id
    _known_player_color_ids[player_index] = color_id
    if player_index == _local_player_index:
        _identity_request_pending = false
        _waiting_room_note = ""
    if _phase == SessionPhase.READY:
        _emit_waiting_room_state()
    _emit_gameplay_player_states()
    _emit_gameplay_turn_state()
    _debug_print_authoritative_gameplay_state("player_identity_changed")

@rpc("authority")
func rpc_energy_allocation_changed(_seq: int, player_index: int, sell_percent: int, turn_number: int) -> void:
    _player_sell_percents[player_index] = sell_percent
    _player_last_allocation_changed_turns[player_index] = turn_number
    if player_index == _local_player_index:
        _energy_allocation_request_pending = false
    _emit_gameplay_turn_state()

@rpc("authority")
func rpc_player_eliminated(_seq: int, player_index: int, _reason: String) -> void:
    _active_players[player_index] = false
    _player_fiat_balances[player_index] = 0.0
    _player_bitcoin_balances[player_index] = 0.0
    _player_tile_positions.erase(player_index)
    if player_index == _current_turn_player_index:
        _pending_action_type = ""
        _pending_action_tile_index = -1
        _pending_property_action.clear()
        _roll_request_pending = false
        _buy_property_request_pending = false
        _pay_toll_request_pending = false
        _end_turn_request_pending = false
    _append_gameplay_event_log_message(
        "%s was eliminated" % _event_log_player_name(player_index),
        player_index,
        "💀"
    )
    _emit_gameplay_pawn_positions()
    _emit_gameplay_player_states()
    _emit_gameplay_turn_state()

@rpc("authority")
func rpc_player_balance_changed(
    _seq: int,
    player_index: int,
    fiat_delta: float,
    btc_delta: float,
    _reason: String
) -> void:
    _player_fiat_balances[player_index] = _player_fiat_balance(player_index) + fiat_delta
    _player_bitcoin_balances[player_index] = _player_bitcoin_balance(player_index) + btc_delta
    _emit_gameplay_player_states()

@rpc("authority")
func rpc_game_ended(_seq: int, winner_index: int, _reason: String, _btc_goal: float, _winner_btc: float) -> void:
    _match_has_finished = true
    _winner_index = winner_index
    _roll_request_pending = false
    _buy_property_request_pending = false
    _pay_toll_request_pending = false
    _end_turn_request_pending = false
    _energy_allocation_request_pending = false
    _pending_action_type = ""
    _pending_action_tile_index = -1
    _pending_property_action.clear()
    if _reason == "btc_goal_reached" and winner_index >= 0:
        _append_gameplay_event_log_message(
            "%s won by reaching %.1f BTC first" % [_event_log_player_name(winner_index), _btc_goal],
            winner_index,
            "🏆️"
        )
    _emit_gameplay_turn_state()

@rpc("authority")
func rpc_board_state(_seq: int, board: Dictionary) -> void:
    _board_state = board.duplicate(true)
    _emit_gameplay_player_states()
    _emit_gameplay_tile_ownership()
    _emit_gameplay_turn_state()

@rpc("authority")
func rpc_game_started(_seq: int, _new_game_id: String, pawn_positions_by_player_index: Dictionary) -> void:
    _ready_request_pending = false
    _match_has_started = true
    _player_tile_positions = pawn_positions_by_player_index.duplicate(true)
    _append_gameplay_event_log_message("🎮️ Game started")
    _update_state(
        SessionPhase.GAME_STARTED,
        "Game starting",
        "The server has started the match and the waiting room is handing off to the gameplay scene.",
        "The gameplay root now owns the player-facing match presentation."
    )
    _emit_gameplay_pawn_positions()
    _emit_gameplay_player_states()
    _debug_print_authoritative_gameplay_state("game_started")

@rpc("authority")
func rpc_turn_started(_seq: int, player_index: int, turn_number: int, _cycle: int) -> void:
    _current_turn_player_index = player_index
    _current_turn_number = turn_number
    _match_has_started = true
    _has_rolled_current_turn = false
    _roll_request_pending = false
    _buy_property_request_pending = false
    _pay_toll_request_pending = false
    _end_turn_request_pending = false
    _pending_action_type = ""
    _pending_action_tile_index = -1
    _pending_property_action.clear()
    _append_gameplay_event_log_message("🚦 %s turn started" % _event_log_player_name(player_index), player_index)
    _emit_gameplay_turn_state()
    _debug_print_authoritative_gameplay_state("turn_started")

@rpc("authority")
func rpc_dice_rolled(_seq: int, die_1: int, die_2: int, total: int) -> void:
    _roll_request_pending = false
    _has_rolled_current_turn = true
    _last_die_1 = die_1
    _last_die_2 = die_2
    _append_gameplay_event_log_message(
        "%s rolled %d + %d = %d" % [
            _event_log_player_name(_current_turn_player_index),
            die_1,
            die_2,
            total,
        ],
        _current_turn_player_index
    )
    _emit_gameplay_turn_state()

@rpc("authority")
func rpc_pawn_moved(_seq: int, _from_tile: int, to_tile: int, _passed_tiles: Array[int]) -> void:
    _player_tile_positions[_current_turn_player_index] = to_tile
    _player_landing_sequences[_current_turn_player_index] = _next_landing_sequence
    _next_landing_sequence += 1
    _emit_gameplay_pawn_positions()
    _emit_gameplay_player_states()
    _debug_print_authoritative_gameplay_state("pawn_moved")

@rpc("authority")
func rpc_tile_landed(
        _seq: int,
        tile_index: int,
        tile_type: String,
        city: String,
        owner_index: int,
        toll_due: float,
        buy_price: float,
        energy_production: int,
        sell_100_fiat: float,
        mine_100_btc: float,
        action_required: String
) -> void:
    _pending_action_type = action_required
    _pending_action_tile_index = tile_index
    var tile: Dictionary = _tile_info_from_board_state(tile_index)
    var resolved_tile_type: String = tile_type if not tile_type.is_empty() else str(tile.get("tile_type", ""))
    var resolved_city: String = city if not city.is_empty() else str(tile.get("city", ""))
    _pending_property_action = _build_property_action_state(
        action_required,
        tile_index,
        resolved_tile_type,
        resolved_city,
        owner_index if owner_index >= 0 else int(tile.get("owner_index", -1)),
        toll_due if toll_due > 0.0 else float(tile.get("toll", 0.0)),
        buy_price if buy_price > 0.0 else float(tile.get("buy_price", 0.0)),
        energy_production if energy_production > 0 else int(tile.get("energy_production", 0)),
        sell_100_fiat if sell_100_fiat > 0.0 else float(tile.get("sell_100_fiat", 0.0)),
        mine_100_btc if mine_100_btc > 0.0 else float(tile.get("mine_100_btc", 0.0))
    )
    _debug_print_property_action_state(
        "tile_landed:built",
        action_required,
        tile_index,
        resolved_tile_type,
        resolved_city,
        _pending_property_action
    )
    if action_required == "end_turn":
        _pending_action_type = ""
        _pending_action_tile_index = -1
    var tile_label: String = city.strip_edges()
    if tile_label.is_empty():
        tile_label = tile_type
    if tile_label.is_empty():
        tile_label = "tile"
    _append_gameplay_event_log_message(
        "%s landed on %s (%d)" % [
            _event_log_player_name(_current_turn_player_index),
            tile_label,
            tile_index,
        ],
        _current_turn_player_index
    )
    _emit_gameplay_turn_state()

@rpc("authority")
func rpc_cycle_started(_seq: int, _cycle: int) -> void:
    pass

@rpc("authority")
func rpc_property_acquired(_seq: int, player_index: int, tile_index: int, price: float) -> void:
    _player_fiat_balances[player_index] = _player_fiat_balance(player_index) - price
    var tiles: Array = _board_state.get("tiles", [])
    if tile_index >= 0 and tile_index < tiles.size():
        var tile: Dictionary = tiles[tile_index]
        tile["owner_index"] = player_index
        tiles[tile_index] = tile
        _board_state["tiles"] = tiles
    _pending_action_type = ""
    _pending_action_tile_index = -1
    _pending_property_action.clear()
    _buy_property_request_pending = false
    _pay_toll_request_pending = false
    _emit_gameplay_player_states()
    _emit_gameplay_tile_ownership()
    _emit_gameplay_turn_state()

@rpc("authority")
func rpc_toll_paid(_seq: int, payer_index: int, owner_index: int, amount: float, payment_type: String) -> void:
    if payment_type == "bitcoin":
        _player_bitcoin_balances[payer_index] = _player_bitcoin_balance(payer_index) - amount
        _player_bitcoin_balances[owner_index] = _player_bitcoin_balance(owner_index) + amount
    else:
        _player_fiat_balances[payer_index] = _player_fiat_balance(payer_index) - amount
        _player_fiat_balances[owner_index] = _player_fiat_balance(owner_index) + amount
    _pending_action_type = ""
    _pending_action_tile_index = -1
    _pending_property_action.clear()
    _pay_toll_request_pending = false
    _emit_gameplay_player_states()
    _emit_gameplay_turn_state()

func _build_property_action_state_from_pending_action(pending_action: Dictionary) -> Dictionary:
    var tile_index: int = int(pending_action.get("tile_index", -1))
    var tile: Dictionary = _tile_info_from_board_state(tile_index)
    var pending_buy_price: float = float(pending_action.get("buy_price", 0.0))
    return _build_property_action_state(
        str(pending_action.get("type", "")),
        tile_index,
        str(tile.get("tile_type", "")),
        str(tile.get("city", "")),
        int(pending_action.get("owner_index", tile.get("owner_index", -1))),
        float(pending_action.get("amount", tile.get("toll", 0.0))),
        pending_buy_price if pending_buy_price > 0.0 else float(tile.get("buy_price", 0.0)),
        int(pending_action.get("energy_production", tile.get("energy_production", 0))),
        float(pending_action.get("sell_100_fiat", tile.get("sell_100_fiat", 0.0))),
        float(pending_action.get("mine_100_btc", tile.get("mine_100_btc", 0.0)))
    )

func _build_property_action_state_from_current_pending_action() -> Dictionary:
    if _pending_action_type != "buy_or_end_turn" and _pending_action_type != "pay_toll":
        return { }
    var tile: Dictionary = _tile_info_from_board_state(_pending_action_tile_index)
    if tile.is_empty():
        return { }
    return _build_property_action_state(
        _pending_action_type,
        _pending_action_tile_index,
        str(tile.get("tile_type", "")),
        str(tile.get("city", "")),
        int(tile.get("owner_index", -1)),
        float(tile.get("toll", 0.0)),
        float(tile.get("buy_price", 0.0)),
        int(tile.get("energy_production", 0)),
        float(tile.get("sell_100_fiat", 0.0)),
        float(tile.get("mine_100_btc", 0.0))
    )

func _build_property_action_state(
        action_type: String,
        tile_index: int,
        tile_type: String,
        city: String,
        owner_index: int,
        toll_due: float,
        buy_price: float,
        energy_production: int,
        sell_100_fiat: float,
        mine_100_btc: float
) -> Dictionary:
    var is_available_to_buy: bool = owner_index < 0
    var is_owned: bool = owner_index >= 0
    var is_owned_by_other_player: bool = is_owned and owner_index != _local_player_index
    return {
        "action_type": action_type,
        "tile_index": tile_index,
        "tile_type": tile_type,
        "city": city,
        "owner_index": owner_index,
        "owner_name": _gameplay_display_name(owner_index) if owner_index >= 0 else "",
        "owner_color_id": _player_color_id(owner_index) if owner_index >= 0 else DEFAULT_IDENTITY_COLOR_ID,
        "toll_due": toll_due,
        "buy_price": buy_price,
        "energy_production": energy_production,
        "sell_100_fiat": sell_100_fiat,
        "mine_100_btc": mine_100_btc,
        "show_buy_overlay": is_available_to_buy,
        "show_toll_overlay": is_owned,
        "show_toll_price": is_owned_by_other_player,
    }

func _refresh_property_action_state(property_action: Dictionary) -> Dictionary:
    var refreshed_property_action: Dictionary = property_action.duplicate(true)
    var owner_index: int = int(refreshed_property_action.get("owner_index", -1))
    var is_available_to_buy: bool = owner_index < 0
    var is_owned: bool = owner_index >= 0
    var is_owned_by_other_player: bool = is_owned and owner_index != _local_player_index
    refreshed_property_action["owner_name"] = _gameplay_display_name(owner_index) if owner_index >= 0 else ""
    refreshed_property_action["owner_color_id"] = _player_color_id(owner_index) if owner_index >= 0 else DEFAULT_IDENTITY_COLOR_ID
    refreshed_property_action["show_buy_overlay"] = is_available_to_buy
    refreshed_property_action["show_toll_overlay"] = is_owned
    refreshed_property_action["show_toll_price"] = is_owned_by_other_player
    return refreshed_property_action

func _tile_info_from_board_state(tile_index: int) -> Dictionary:
    var tiles: Array = _board_state.get("tiles", [])
    if tile_index < 0 or tile_index >= tiles.size():
        return { }
    return (tiles[tile_index] as Dictionary).duplicate(true)

func _debug_print_property_action_state(
        context: String,
        action_type: String,
        tile_index: int,
        tile_type: String,
        city: String,
        property_action: Dictionary
) -> void:
    if not _should_print_debug_gameplay_state():
        return
    print(
        "[session:%s] action=%s tile=%d type=%s city=%s property_action_empty=%s property_action=%s board_tiles=%d pending=%s/%d"
        % [
            context,
            action_type,
            tile_index,
            tile_type,
            city,
            property_action.is_empty(),
            str(property_action),
            int((_board_state.get("tiles", []) as Array).size()),
            _pending_action_type if not _pending_action_type.is_empty() else "-",
            _pending_action_tile_index,
        ]
    )

func _update_state(
    phase: int,
    title: String,
    detail: String,
    note: String
) -> void:
    _phase = phase as SessionPhase
    _session_state = StatusCardState.new(title, detail, note)
    session_state_changed.emit(get_session_state())

func _apply_waiting_room_snapshot(snapshot: Dictionary) -> void:
    _room_game_id = str(snapshot.get("game_id", _room_game_id))
    _match_has_started = bool(snapshot.get("has_started", false))
    _match_has_finished = bool(snapshot.get("has_finished", false))
    _winner_index = int(snapshot.get("winner_index", -1))
    _current_turn_number = int(snapshot.get("turn_number", _current_turn_number))
    _current_turn_player_index = int(snapshot.get("current_player_index", _current_turn_player_index))
    var players: Array = snapshot.get("players", [])
    var snapshot_local_player_index: int = -1
    _room_capacity = max(_room_capacity, players.size())
    if _ready_players.size() < _room_capacity:
        _ready_players.resize(_room_capacity)
    for ready_index in range(_ready_players.size()):
        if _ready_players[ready_index] == null:
            _ready_players[ready_index] = false

    for player_variant in players:
        var player_in_snapshot: Dictionary = player_variant
        var player_index: int = int(player_in_snapshot.get("player_index", -1))
        if player_index < 0 or player_index >= _room_capacity:
            continue
        _active_players[player_index] = bool(player_in_snapshot.get("is_active", true))
        var is_joined: bool = bool(player_in_snapshot.get("joined", false))
        _joined_players[player_index] = is_joined
        if is_joined:
            var player_id: String = str(player_in_snapshot.get("player_id", ""))
            if not player_id.is_empty():
                _known_player_ids[player_index] = player_id
                if not _current_player_id.is_empty() and player_id == _current_player_id:
                    snapshot_local_player_index = player_index
        _known_player_display_names[player_index] = str(player_in_snapshot.get("display_name", ""))
        _known_player_icon_ids[player_index] = int(player_in_snapshot.get("icon_id", -1))
        _known_player_color_ids[player_index] = int(player_in_snapshot.get("color_id", -1))
        _player_fiat_balances[player_index] = float(
            player_in_snapshot.get("fiat_balance", GameEconomyConfigModel.INITIAL_FIAT_BALANCE)
        )
        _player_bitcoin_balances[player_index] = float(
            player_in_snapshot.get("bitcoin_balance", GameEconomyConfigModel.INITIAL_BITCOIN_BALANCE)
        )
        _player_sell_percents[player_index] = int(player_in_snapshot.get("sell_percent", 50))
        _player_last_allocation_changed_turns[player_index] = int(
            player_in_snapshot.get("last_turn_number_allocation_changed", -1)
        )
        if bool(player_in_snapshot.get("ready", false)):
            _ready_players[player_index] = true
    if snapshot_local_player_index >= 0:
        _local_player_index = snapshot_local_player_index
    _emit_waiting_room_state()

func _emit_waiting_room_state() -> void:
    var slots: Array = []
    var capacity: int = _room_capacity
    if capacity <= 0 and _local_player_index >= 0:
        capacity = _local_player_index + 1

    for player_index in range(capacity):
        var is_local: bool = player_index == _local_player_index
        var is_ready: bool = _is_player_ready(player_index)
        var known_player_id: String = str(_known_player_ids.get(player_index, ""))
        var known_display_name: String = str(_known_player_display_names.get(player_index, "")).strip_edges()
        var icon_id: int = _player_icon_id(player_index)
        var color_id: int = _player_color_id(player_index)
        var player_id: String = known_player_id
        var is_known_player: bool = is_local or not known_player_id.is_empty() or is_ready
        var display_name: String = "Awaiting player"
        var status_text: String = "Open seat"

        if is_local:
            display_name = known_display_name if not known_display_name.is_empty() else "You"
            status_text = "Ready" if is_ready else "Waiting"
            if player_id.is_empty():
                player_id = _current_player_id
        elif not known_player_id.is_empty():
            display_name = known_display_name if not known_display_name.is_empty() else "Player"
            status_text = "Ready" if is_ready else "Joined"
        elif is_ready:
            display_name = "Player %d" % (player_index + 1)
            status_text = "Ready"

        slots.append(
            WaitingRoomSlotModel.new(
                player_index,
                display_name,
                player_id,
                status_text,
                is_local,
                is_ready,
                is_known_player,
                icon_id,
                color_id
            )
        )

    var ready_count: int = 0
    for ready_player in _ready_players:
        if bool(ready_player):
            ready_count += 1

    var local_display_name: String = _player_display_name(_local_player_index)
    if local_display_name.is_empty():
        local_display_name = "Player"

    _waiting_room_state = WaitingRoomStateModel.new(
        _room_game_id,
        capacity,
        _current_player_id,
        _local_player_index,
        local_display_name,
        _player_icon_id(_local_player_index),
        _player_color_id(_local_player_index),
        _local_player_index >= 0 and _is_player_ready(_local_player_index),
        ready_count,
        slots,
        _waiting_room_footer_note(),
        _ready_request_pending
    )
    waiting_room_state_changed.emit(get_waiting_room_state())

func _emit_gameplay_turn_state() -> void:
    gameplay_turn_state_changed.emit(get_gameplay_turn_state())

func _emit_gameplay_player_states() -> void:
    gameplay_player_states_changed.emit(get_gameplay_player_states())

func _emit_gameplay_event_log_messages() -> void:
    gameplay_event_log_changed.emit(get_gameplay_event_log_messages())

func _emit_gameplay_pawn_positions() -> void:
    gameplay_pawn_positions_changed.emit(get_gameplay_pawn_positions())

func _emit_gameplay_tile_ownership() -> void:
    gameplay_tile_ownership_changed.emit(get_gameplay_tile_owner_indices())

func _tile_owner_indices_by_tile_index() -> Dictionary:
    var tile_owner_indices_by_tile_index: Dictionary = { }
    var tiles: Array = _board_state.get("tiles", [])
    for tile_index in range(tiles.size()):
        var tile_variant: Variant = tiles[tile_index]
        if not (tile_variant is Dictionary):
            continue
        var tile: Dictionary = tile_variant
        var owner_index: int = int(tile.get("owner_index", -1))
        if owner_index < 0:
            continue
        tile_owner_indices_by_tile_index[tile_index] = owner_index
    return tile_owner_indices_by_tile_index

func _is_player_ready(player_index: int) -> bool:
    if player_index < 0 or player_index >= _ready_players.size():
        return false
    return bool(_ready_players[player_index])

func _set_player_ready(player_index: int, is_ready: bool) -> void:
    while _ready_players.size() <= player_index:
        _ready_players.append(false)
    _ready_players[player_index] = is_ready

func _short_player_id(player_id: String) -> String:
    if player_id.length() <= 14:
        return player_id
    return "%s...%s" % [player_id.substr(0, 6), player_id.substr(player_id.length() - 4, 4)]

func _waiting_room_footer_note() -> String:
    if not _waiting_room_note.is_empty():
        return _waiting_room_note
    return ""

func _is_waiting_room_connection_interactive() -> bool:
    if _waiting_room_reconnect_active:
        return false
    if _session_transport == null:
        return false
    return _session_transport.is_connected_to_server()

func _player_display_name(player_index: int) -> String:
    return str(_known_player_display_names.get(player_index, "")).strip_edges()

func _player_icon_id(player_index: int) -> int:
    var icon_id: int = int(_known_player_icon_ids.get(player_index, -1))
    if icon_id < 0:
        return DEFAULT_IDENTITY_ICON_ID
    return icon_id

func _player_color_id(player_index: int) -> int:
    var color_id: int = int(_known_player_color_ids.get(player_index, -1))
    if color_id < 0:
        if player_index >= 0:
            return player_index
        return DEFAULT_IDENTITY_COLOR_ID
    return color_id

func _player_fiat_balance(player_index: int) -> float:
    return float(_player_fiat_balances.get(player_index, GameEconomyConfigModel.INITIAL_FIAT_BALANCE))

func _player_energy_balance(player_index: int) -> int:
    return _owned_energy_amount(player_index)

func _player_bitcoin_balance(player_index: int) -> float:
    return float(_player_bitcoin_balances.get(player_index, GameEconomyConfigModel.INITIAL_BITCOIN_BALANCE))

func _player_sell_percent(player_index: int) -> int:
    return int(_player_sell_percents.get(player_index, 50))

func _player_last_allocation_changed_turn(player_index: int) -> int:
    return int(_player_last_allocation_changed_turns.get(player_index, -1))

func _owned_energy_amount(player_index: int) -> int:
    return int(_owned_tile_economy_totals(player_index).get("energy_amount", 0))

func _owned_tile_economy_totals(player_index: int) -> Dictionary:
    var tiles: Array = _board_state.get("tiles", [])
    var total_energy_amount: int = 0
    var total_sell_100_fiat: float = 0.0
    var total_mine_100_btc: float = 0.0
    for tile_variant in tiles:
        var tile: Dictionary = tile_variant
        if int(tile.get("owner_index", -1)) != player_index:
            continue
        total_energy_amount += int(tile.get("energy_production", 0))
        total_sell_100_fiat += float(tile.get("sell_100_fiat", 0.0))
        total_mine_100_btc += float(tile.get("mine_100_btc", 0.0))
    return {
        "energy_amount": total_energy_amount,
        "sell_100_fiat": total_sell_100_fiat,
        "mine_100_btc": total_mine_100_btc,
    }

func _player_landing_sequence(player_index: int) -> int:
    return int(_player_landing_sequences.get(player_index, player_index + 1))

func _is_player_active(player_index: int) -> bool:
    return bool(_active_players.get(player_index, true))

func _gameplay_display_name(player_index: int) -> String:
    var display_name: String = _player_display_name(player_index)
    if not display_name.is_empty():
        return display_name
    if player_index == _local_player_index:
        return "You"
    return "Player %d" % (player_index + 1)

func _event_log_player_name(player_index: int) -> String:
    var display_name: String = _player_display_name(player_index)
    if not display_name.is_empty():
        return display_name
    return "Player %d" % (player_index + 1)

func _clone_gameplay_player_states(states: Array) -> Array:
    var cloned_states: Array = []
    for state_variant in states:
        cloned_states.append(state_variant.clone())
    return cloned_states

func _append_gameplay_event_log_message(message: String, player_index: int = -1, icon: String = "") -> void:
    if not _active_reconnect_event_log_key.is_empty() and not _is_gameplay_reconnect_in_progress():
        _active_reconnect_event_log_key = ""
    _gameplay_event_log_messages.append({
        "message": message,
        "color_id": _player_color_id(player_index) if player_index >= 0 else -1,
        "icon": icon,
    })
    _emit_gameplay_event_log_messages()

func _upsert_gameplay_event_log_message(
    key: String,
    message: String,
    player_index: int = -1,
    icon: String = ""
) -> void:
    for event_index in range(_gameplay_event_log_messages.size()):
        var event_entry: Variant = _gameplay_event_log_messages[event_index]
        if not (event_entry is Dictionary):
            continue
        var event_dictionary: Dictionary = event_entry
        if str(event_dictionary.get("key", "")) != key:
            continue
        event_dictionary["message"] = message
        event_dictionary["color_id"] = _player_color_id(player_index) if player_index >= 0 else -1
        event_dictionary["icon"] = icon
        _gameplay_event_log_messages[event_index] = event_dictionary
        _emit_gameplay_event_log_messages()
        return

    _gameplay_event_log_messages.append({
        "key": key,
        "message": message,
        "color_id": _player_color_id(player_index) if player_index >= 0 else -1,
        "icon": icon,
    })
    _emit_gameplay_event_log_messages()

func _append_gameplay_snapshot_winner_message(winner_index: int, end_reason: String) -> void:
    if end_reason == "btc_goal_reached":
        _append_gameplay_event_log_message(
            "%s won by reaching %.1f BTC first" % [_event_log_player_name(winner_index), _player_bitcoin_balance(winner_index)],
            winner_index,
            "🏆️"
        )
        return
    if end_reason == "last_player_standing":
        _append_gameplay_event_log_message(
            "%s won as the last active player remaining" % _event_log_player_name(winner_index),
            winner_index,
            "🏆️"
        )
        return
    _append_gameplay_event_log_message(
        "%s won the match" % _event_log_player_name(winner_index),
        winner_index,
        "🏆️"
    )

func _apply_player_positions_snapshot(snapshot: Dictionary) -> void:
    _player_tile_positions.clear()
    _player_landing_sequences.clear()
    var players: Array = snapshot.get("players", [])
    var max_landing_sequence: int = 0
    for player_variant in players:
        var player_in_snapshot: Dictionary = player_variant
        var player_index: int = int(player_in_snapshot.get("player_index", -1))
        if player_index < 0:
            continue
        _active_players[player_index] = bool(player_in_snapshot.get("is_active", true))
        var tile_index: int = int(player_in_snapshot.get("position", -1))
        var landing_sequence: int = int(player_in_snapshot.get("landing_sequence", player_index + 1))
        _player_landing_sequences[player_index] = landing_sequence
        max_landing_sequence = max(max_landing_sequence, landing_sequence)
        if not _is_player_active(player_index):
            continue
        if tile_index < 0:
            continue
        _player_tile_positions[player_index] = tile_index
    _next_landing_sequence = int(snapshot.get("next_landing_seq", max_landing_sequence + 1))
    if _next_landing_sequence <= max_landing_sequence:
        _next_landing_sequence = max_landing_sequence + 1

func _debug_print_authoritative_gameplay_state(context: String) -> void:
    if not _should_print_debug_gameplay_state():
        return
    var player_states: Array = get_gameplay_player_states()
    var player_summaries: Array[String] = []
    for state_variant in player_states:
        if state_variant == null:
            continue
        var player_state: GamePlayerHudStateModel = state_variant
        player_summaries.append(
            "p%d%s color=%d icon=%d fiat=%.2f energy=%d btc=%.8f" % [
                player_state.player_index,
                " local" if player_state.is_local else "",
                player_state.color_id,
                player_state.icon_id,
                player_state.fiat_balance,
                player_state.energy_amount,
                player_state.bitcoin_balance,
            ]
        )

    var pawn_summaries: Array[String] = []
    var pawn_player_indices: Array = _player_tile_positions.keys()
    pawn_player_indices.sort()
    for player_index_variant in pawn_player_indices:
        var player_index: int = int(player_index_variant)
        pawn_summaries.append("p%d->%d" % [player_index, int(_player_tile_positions[player_index_variant])])

    var board_size: int = int(_board_state.get("size", -1))
    var tile_count: int = int((_board_state.get("tiles", []) as Array).size())
    print(
        "[session:%s] started=%s finished=%s turn=%d current=%d local=%d board=%d tiles=%d pending=%s/%d players=[%s] pawns=[%s]" % [
            context,
            _match_has_started,
            _match_has_finished,
            _current_turn_number,
            _current_turn_player_index,
            _local_player_index,
            board_size,
            tile_count,
            _pending_action_type if not _pending_action_type.is_empty() else "-",
            _pending_action_tile_index,
            ", ".join(player_summaries),
            ", ".join(pawn_summaries),
        ]
    )


func _should_print_debug_gameplay_state() -> bool:
    return OS.has_environment("EVANOPOLIS_DEBUG_GAMEPLAY") or _has_debug_argument()

func _has_debug_argument() -> bool:
    for argument in OS.get_cmdline_args():
        if argument == DEBUG_GAMEPLAY_ARGUMENT or argument.begins_with("%s=" % DEBUG_GAMEPLAY_ARGUMENT):
            return true
    for argument in OS.get_cmdline_user_args():
        if argument == DEBUG_GAMEPLAY_ARGUMENT or argument.begins_with("%s=" % DEBUG_GAMEPLAY_ARGUMENT):
            return true
    return false

func _is_gameplay_connection_interactive() -> bool:
    return _gameplay_connection_phase == GameplayConnectionPhase.CONNECTED

func _is_gameplay_reconnect_in_progress() -> bool:
    return (
        _gameplay_connection_phase == GameplayConnectionPhase.CONNECTION_LOST
        or _gameplay_connection_phase == GameplayConnectionPhase.RECONNECTING
        or _gameplay_connection_phase == GameplayConnectionPhase.RESYNCING
    )

func _gameplay_connection_phase_name() -> String:
    match _gameplay_connection_phase:
        GameplayConnectionPhase.CONNECTED:
            return "connected"
        GameplayConnectionPhase.CONNECTION_LOST:
            return "connection_lost"
        GameplayConnectionPhase.RECONNECTING:
            return "reconnecting"
        GameplayConnectionPhase.RESYNCING:
            return "resyncing"
        GameplayConnectionPhase.FAILED:
            return "failed"
    return "connected"

func _set_gameplay_connection_phase(phase: int) -> void:
    _gameplay_connection_phase = phase as GameplayConnectionPhase

func _clear_gameplay_request_pending_flags() -> void:
    _roll_request_pending = false
    _buy_property_request_pending = false
    _pay_toll_request_pending = false
    _end_turn_request_pending = false
    _energy_allocation_request_pending = false

func _begin_gameplay_reconnect() -> void:
    if _gameplay_connection_phase == GameplayConnectionPhase.FAILED:
        return
    if _is_gameplay_reconnect_in_progress():
        return
    _set_gameplay_connection_phase(GameplayConnectionPhase.CONNECTION_LOST)
    _gameplay_reconnect_attempts = 0
    _clear_gameplay_request_pending_flags()
    if _active_reconnect_event_log_key.is_empty():
        _reconnect_event_log_sequence += 1
        _active_reconnect_event_log_key = "%s%d" % [RECONNECT_EVENT_LOG_KEY_PREFIX, _reconnect_event_log_sequence]
    _upsert_gameplay_event_log_message(
        _current_reconnect_event_log_key(),
        "Connection lost. Reconnecting.",
        -1,
        "⚠️"
    )
    _emit_gameplay_turn_state()
    _start_gameplay_reconnect_attempt()

func _begin_waiting_room_reconnect() -> void:
    if _phase != SessionPhase.READY:
        return
    if _waiting_room_reconnect_active:
        _waiting_room_note = "Connection lost. Reconnecting."
        _emit_waiting_room_state()
        return
    _waiting_room_reconnect_active = true
    _waiting_room_reconnect_attempts = 0
    _ready_request_pending = false
    _identity_request_pending = false
    _waiting_room_note = "Connection lost. Reconnecting."
    _emit_waiting_room_state()
    _start_waiting_room_reconnect_attempt()

func _schedule_waiting_room_reconnect_retry() -> void:
    if _waiting_room_reconnect_timer == null:
        _waiting_room_reconnect_timer = Timer.new()
        _waiting_room_reconnect_timer.one_shot = true
        add_child(_waiting_room_reconnect_timer)
        _waiting_room_reconnect_timer.timeout.connect(_on_waiting_room_reconnect_timer_timeout)
    var retry_delay_seconds: float = _next_waiting_room_reconnect_delay_seconds()
    var next_attempt_number: int = _waiting_room_reconnect_attempts + 1
    _waiting_room_note = "Reconnect attempt %d failed. Retrying in %.0fs." % [
        next_attempt_number - 1,
        retry_delay_seconds,
    ]
    _waiting_room_reconnect_timer.start(retry_delay_seconds)
    _emit_waiting_room_state()

func _start_waiting_room_reconnect_attempt() -> void:
    assert(_launch_payload)
    _waiting_room_reconnect_attempts += 1
    _session_transport.disconnect_transport()
    _session_transport.connect_to_server(_launch_payload._game_server_url)
    _emit_waiting_room_state()

func _on_waiting_room_reconnect_timer_timeout() -> void:
    _start_waiting_room_reconnect_attempt()

func _fail_waiting_room_reconnect(message: String) -> void:
    _waiting_room_reconnect_active = false
    _waiting_room_note = message
    _emit_waiting_room_state()

func _next_waiting_room_reconnect_delay_seconds() -> float:
    if _waiting_room_reconnect_attempts <= 0:
        return GAMEPLAY_RECONNECT_DELAYS_SECONDS[0]
    var delay_index: int = mini(_waiting_room_reconnect_attempts - 1, GAMEPLAY_RECONNECT_DELAYS_SECONDS.size() - 1)
    return float(GAMEPLAY_RECONNECT_DELAYS_SECONDS[delay_index])

func _schedule_gameplay_reconnect_retry() -> void:
    if _gameplay_reconnect_timer == null:
        _gameplay_reconnect_timer = Timer.new()
        _gameplay_reconnect_timer.one_shot = true
        add_child(_gameplay_reconnect_timer)
        _gameplay_reconnect_timer.timeout.connect(_on_gameplay_reconnect_timer_timeout)
    var retry_delay_seconds: float = _next_gameplay_reconnect_delay_seconds()
    var next_attempt_number: int = _gameplay_reconnect_attempts + 1
    _set_gameplay_connection_phase(GameplayConnectionPhase.RECONNECTING)
    _upsert_gameplay_event_log_message(
        _current_reconnect_event_log_key(),
        "Reconnect attempt %d failed. Retrying in %.0fs." % [next_attempt_number - 1, retry_delay_seconds],
        -1,
        "🔄"
    )
    _gameplay_reconnect_timer.start(retry_delay_seconds)
    _emit_gameplay_turn_state()

func _start_gameplay_reconnect_attempt() -> void:
    assert(_launch_payload)
    _gameplay_reconnect_attempts += 1
    _set_gameplay_connection_phase(GameplayConnectionPhase.RECONNECTING)
    _session_transport.disconnect_transport()
    _session_transport.connect_to_server(_launch_payload._game_server_url)
    _emit_gameplay_turn_state()

func _on_gameplay_reconnect_timer_timeout() -> void:
    _start_gameplay_reconnect_attempt()

func _fail_gameplay_reconnect(message: String) -> void:
    _set_gameplay_connection_phase(GameplayConnectionPhase.FAILED)
    _clear_gameplay_request_pending_flags()
    _upsert_gameplay_event_log_message(_current_reconnect_event_log_key(), message, -1, "⚠️")
    _active_reconnect_event_log_key = ""
    _emit_gameplay_turn_state()

func _next_gameplay_reconnect_delay_seconds() -> float:
    if _gameplay_reconnect_attempts <= 0:
        return GAMEPLAY_RECONNECT_DELAYS_SECONDS[0]
    var delay_index: int = mini(_gameplay_reconnect_attempts - 1, GAMEPLAY_RECONNECT_DELAYS_SECONDS.size() - 1)
    return float(GAMEPLAY_RECONNECT_DELAYS_SECONDS[delay_index])

func _current_reconnect_event_log_key() -> String:
    assert(not _active_reconnect_event_log_key.is_empty())
    return _active_reconnect_event_log_key


func _try_schedule_retry(message: String) -> bool:
    if _connect_attempts >= MAX_CONNECT_ATTEMPTS:
        return false

    if _retry_timer == null:
        _retry_timer = Timer.new()
        _retry_timer.one_shot = true
        add_child(_retry_timer)
        _retry_timer.timeout.connect(_on_retry_timer_timeout)

    _update_state(
        SessionPhase.RETRYING,
        "Retrying session connection",
        message,
        "The client will retry the transport handshake once before failing the session."
    )
    _retry_timer.start(RETRY_DELAY_SECONDS)
    return true

func _on_retry_timer_timeout() -> void:
    _connect_to_server()

func _fail_session(message: String) -> void:
    _update_state(
        SessionPhase.FAILED,
        "Session check failed",
        message,
        "The client stopped before waiting room because the server handshake did not complete."
    )
