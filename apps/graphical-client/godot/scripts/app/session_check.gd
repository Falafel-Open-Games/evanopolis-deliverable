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

const DEFAULT_IDENTITY_ICON_ID: int = 11
const DEFAULT_IDENTITY_COLOR_ID: int = 0

signal session_state_changed(state: StatusCardState)
signal waiting_room_state_changed(state: WaitingRoomStateModel)
signal gameplay_turn_state_changed(turn_state: Dictionary)
signal gameplay_player_states_changed(states: Array)
signal gameplay_event_log_changed(messages: Array)

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

const MAX_CONNECT_ATTEMPTS: int = 2
const RETRY_DELAY_SECONDS: float = 0.75

@export var boot_node: AppBoot

var _launch_payload: LaunchPayloadModel
var _session_state: StatusCardState = StatusCardState.new(
    "Waiting for launch data",
    "The session checker is idle until AppBoot publishes a launch payload.",
    "This is the first server-backed step after the wrapper handoff."
)
var _phase: SessionPhase
var _current_player_id: String
var _local_player_index: int
var _has_auth_ok: bool
var _has_join_accepted: bool
var _has_snapshot: bool
var _connect_attempts: int
var _retry_timer: Timer
var _session_transport: SessionTransport
var _room_game_id: String
var _room_capacity: int
var _known_player_ids: Dictionary = { }
var _joined_players: Dictionary = { }
var _known_player_display_names: Dictionary = { }
var _known_player_icon_ids: Dictionary = { }
var _known_player_color_ids: Dictionary = { }
var _player_fiat_balances: Dictionary = { }
var _player_energy_balances: Dictionary = { }
var _player_bitcoin_balances: Dictionary = { }
var _ready_players: Array = []
var _current_turn_number: int = 1
var _current_turn_player_index: int = 0
var _waiting_room_state: WaitingRoomStateModel
var _waiting_room_note: String = ""
var _ready_request_pending: bool = false
var _identity_request_pending: bool = false
var _match_has_started: bool = false
var _match_has_finished: bool = false
var _gameplay_event_log_messages: Array = []

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
    return {
        "turn_number": _current_turn_number,
        "current_player_index": _current_turn_player_index,
        "current_player_name": current_player_name,
        "is_local_turn": _current_turn_player_index == _local_player_index,
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
                _player_bitcoin_balance(player_index)
            )
        )
    return _clone_gameplay_player_states(states)

func get_gameplay_event_log_messages() -> Array:
    return _gameplay_event_log_messages.duplicate()

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
    if _local_player_index < 0:
        return false
    if _ready_request_pending:
        return false
    return not _is_player_ready(_local_player_index)

func can_request_player_identity() -> bool:
    if _phase != SessionPhase.READY:
        return false
    if _local_player_index < 0:
        return false
    return not _identity_request_pending

func request_player_ready() -> void:
    assert(_launch_payload)
    assert(_current_player_id != "")
    assert(_local_player_index >= 0)
    if not can_request_player_ready():
        return

    _ready_request_pending = true
    _waiting_room_note = "Sending ready signal to the game server."
    _emit_waiting_room_state()
    rpc_id(1, "rpc_player_ready", _launch_payload._game_id, _current_player_id)

func request_player_identity(display_name: String, icon_id: int, color_id: int) -> void:
    assert(_launch_payload)
    assert(_current_player_id != "")
    assert(_local_player_index >= 0)
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
    _player_energy_balances.clear()
    _player_bitcoin_balances.clear()
    _ready_players.clear()
    _current_turn_number = 1
    _current_turn_player_index = 0
    _waiting_room_state = null
    _waiting_room_note = ""
    _ready_request_pending = false
    _identity_request_pending = false
    _match_has_started = false
    _match_has_finished = false
    _gameplay_event_log_messages.clear()
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
    _update_state(
        SessionPhase.AUTHENTICATING,
        "Authenticating session",
        "The client is sending `rpc_auth(...)` with the launch token.",
        "The game server will verify the token with the auth service before join."
    )
    rpc_id(1, "rpc_auth", _launch_payload._token)

func _on_connection_failed() -> void:
    if _try_schedule_retry("The multiplayer connection to the game server failed."):
        return
    _fail_session("The multiplayer connection to the game server failed.")

func _on_server_disconnected() -> void:
    if _phase == SessionPhase.READY or _phase == SessionPhase.GAME_STARTED:
        return
    if _try_schedule_retry("The game server disconnected during session setup."):
        return
    _fail_session("The game server disconnected during session setup.")

@rpc("authority")
func rpc_auth_ok(player_id: String, _exp: int) -> void:
    assert(_launch_payload)
    if player_id.strip_edges() == "":
        _fail_session("The game server returned an empty player id.")
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
    _fail_session("Authentication failed: %s" % reason)

@rpc("authority")
func rpc_join_accepted(_seq: int, player_id: String, player_index: int, last_seq: int) -> void:
    assert(_launch_payload)
    if not _has_auth_ok:
        _fail_session("Received join success before auth completed.")
        return
    if player_id != _current_player_id:
        _fail_session("The server accepted a different player id than the one that authenticated.")
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
    _fail_session("The game server rejected the session: %s" % reason)

@rpc("authority")
func rpc_state_snapshot(_seq: int, snapshot: Dictionary) -> void:
    _has_snapshot = true
    _current_turn_number = int(snapshot.get("turn_number", _current_turn_number))
    _current_turn_player_index = int(snapshot.get("current_player_index", _current_turn_player_index))
    _apply_waiting_room_snapshot(snapshot)
    _rebuild_gameplay_event_log_from_state()
    _emit_gameplay_turn_state()
    _emit_gameplay_player_states()

@rpc("authority")
func rpc_sync_complete(_seq: int, _final_seq: int) -> void:
    if not _has_join_accepted:
        _fail_session("Received sync completion before join acceptance.")
        return
    if not _has_snapshot:
        _fail_session("Received sync completion before state snapshot.")
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
func rpc_game_started(_seq: int, _new_game_id: String) -> void:
    _ready_request_pending = false
    _match_has_started = true
    _append_gameplay_event_log_message("🎮️ Game started")
    _update_state(
        SessionPhase.GAME_STARTED,
        "Game starting",
        "The server has started the match and the waiting room is handing off to the gameplay scene.",
        "The gameplay root now owns the player-facing match presentation."
    )
    _emit_gameplay_player_states()

@rpc("authority")
func rpc_turn_started(_seq: int, player_index: int, turn_number: int, _cycle: int) -> void:
    _current_turn_player_index = player_index
    _current_turn_number = turn_number
    _match_has_started = true
    _append_gameplay_event_log_message("🔄 %s turn started" % _event_log_player_name(player_index))
    _emit_gameplay_turn_state()

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
    _current_turn_number = int(snapshot.get("turn_number", _current_turn_number))
    _current_turn_player_index = int(snapshot.get("current_player_index", _current_turn_player_index))
    var players: Array = snapshot.get("players", [])
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
        var is_joined: bool = bool(player_in_snapshot.get("joined", false))
        _joined_players[player_index] = is_joined
        if is_joined:
            var player_id: String = str(player_in_snapshot.get("player_id", ""))
            if not player_id.is_empty():
                _known_player_ids[player_index] = player_id
        _known_player_display_names[player_index] = str(player_in_snapshot.get("display_name", ""))
        _known_player_icon_ids[player_index] = int(player_in_snapshot.get("icon_id", -1))
        _known_player_color_ids[player_index] = int(player_in_snapshot.get("color_id", -1))
        _player_fiat_balances[player_index] = float(
            player_in_snapshot.get("fiat_balance", GameEconomyConfigModel.INITIAL_FIAT_BALANCE)
        )
        _player_energy_balances[player_index] = int(
            player_in_snapshot.get(
                "energy_balance",
                player_in_snapshot.get("energy", GameEconomyConfigModel.INITIAL_ENERGY_BALANCE)
            )
        )
        _player_bitcoin_balances[player_index] = float(
            player_in_snapshot.get("bitcoin_balance", GameEconomyConfigModel.INITIAL_BITCOIN_BALANCE)
        )
        if bool(player_in_snapshot.get("ready", false)):
            _ready_players[player_index] = true
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
    return "Roster names and identity customization will improve once the server snapshot includes richer waiting-room metadata."

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
        return DEFAULT_IDENTITY_COLOR_ID
    return color_id

func _player_fiat_balance(player_index: int) -> float:
    return float(_player_fiat_balances.get(player_index, GameEconomyConfigModel.INITIAL_FIAT_BALANCE))

func _player_energy_balance(player_index: int) -> int:
    return int(_player_energy_balances.get(player_index, GameEconomyConfigModel.INITIAL_ENERGY_BALANCE))

func _player_bitcoin_balance(player_index: int) -> float:
    return float(_player_bitcoin_balances.get(player_index, GameEconomyConfigModel.INITIAL_BITCOIN_BALANCE))

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

func _rebuild_gameplay_event_log_from_state() -> void:
    _gameplay_event_log_messages.clear()
    if not _match_has_started:
        _emit_gameplay_event_log_messages()
        return

    _gameplay_event_log_messages.append("🎮️ Game started")
    _gameplay_event_log_messages.append(
        "🔄 %s turn started" % _event_log_player_name(_current_turn_player_index)
    )
    _emit_gameplay_event_log_messages()

func _append_gameplay_event_log_message(message: String) -> void:
    _gameplay_event_log_messages.append(message)
    _emit_gameplay_event_log_messages()


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
