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
const LaunchPayloadModel = preload("res://scripts/app/models/launch_payload.gd")
const WaitingRoomStateModel = preload("res://scripts/app/models/waiting_room_state.gd")
const WaitingRoomSlotModel = preload("res://scripts/app/models/waiting_room_slot.gd")
const SessionTransport = preload("res://scripts/app/session_transport.gd")

signal session_state_changed(state: StatusCardState)
signal waiting_room_state_changed(state: WaitingRoomStateModel)

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
var _ready_players: Array = []
var _waiting_room_state: WaitingRoomStateModel
var _waiting_room_note: String = ""
var _ready_request_pending: bool = false

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

func is_waiting_for_launch() -> bool:
    return _phase == SessionPhase.WAITING_FOR_LAUNCH

func is_waiting_room_active() -> bool:
    return _phase == SessionPhase.READY

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
    _ready_players.clear()
    _waiting_room_state = null
    _waiting_room_note = ""
    _ready_request_pending = false
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
        _ready_request_pending = false
        _waiting_room_note = "Ready action rejected: %s" % reason
        _emit_waiting_room_state()
        return
    _fail_session("The game server rejected the session: %s" % reason)

@rpc("authority")
func rpc_state_snapshot(_seq: int, snapshot: Dictionary) -> void:
    _has_snapshot = true
    _apply_waiting_room_snapshot(snapshot)

@rpc("authority")
func rpc_sync_complete(_seq: int, _final_seq: int) -> void:
    if not _has_join_accepted:
        _fail_session("Received sync completion before join acceptance.")
        return
    if not _has_snapshot:
        _fail_session("Received sync completion before state snapshot.")
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
    if _phase == SessionPhase.READY:
        _emit_waiting_room_state()

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
func rpc_game_started(_seq: int, _new_game_id: String) -> void:
    _ready_request_pending = false
    _update_state(
        SessionPhase.GAME_STARTED,
        "Game starting",
        "The server has started the match and the waiting room is handing off to the next client stage.",
        "The next milestone will replace this handoff note with the actual gameplay root."
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
        if bool(player_in_snapshot.get("joined", false)):
            var player_id: String = str(player_in_snapshot.get("player_id", ""))
            if not player_id.is_empty():
                _known_player_ids[player_index] = player_id
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
        var player_id: String = known_player_id
        var is_known_player: bool = is_local or not known_player_id.is_empty() or is_ready
        var display_name: String = "Awaiting player"
        var status_text: String = "Open seat"

        if is_local:
            display_name = "You"
            status_text = "Ready" if is_ready else "Waiting"
            if player_id.is_empty():
                player_id = _current_player_id
        elif not known_player_id.is_empty():
            display_name = "Player"
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
                is_known_player
            )
        )

    var ready_count: int = 0
    for ready_player in _ready_players:
        if bool(ready_player):
            ready_count += 1

    _waiting_room_state = WaitingRoomStateModel.new(
        _room_game_id,
        capacity,
        _current_player_id,
        _local_player_index,
        _local_player_index >= 0 and _is_player_ready(_local_player_index),
        ready_count,
        slots,
        _waiting_room_footer_note(),
        _ready_request_pending
    )
    waiting_room_state_changed.emit(get_waiting_room_state())

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
