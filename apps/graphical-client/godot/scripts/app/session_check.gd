extends "res://scripts/app/headless_rpc_client.gd"

## Session admission controller for the graphical client.
##
## This module sits between `AppBoot` and the first player-facing session UI.
## It does not render the waiting room or gameplay. Its job is to take a valid
## launch payload, perform the minimum server-backed handshake, and publish a
## small status-card state for the current connection phase.
##
## Current responsibilities:
## - wait for `AppBoot` to publish a `LaunchPayload`
## - connect to the game server transport
## - send `rpc_auth(token)`
## - send `rpc_join(game_id, player_id)` after auth success
## - request `rpc_sync_request(...)` after join success
## - publish readable states such as connecting, authenticating, syncing, ready,
##   or failed
##
## This controller is intentionally narrow. Later stages such as the waiting
## room and gameplay should consume the successful connected state it produces,
## rather than expanding this file into a general-purpose match-state module.

const StatusCardState = preload("res://scripts/app/models/status_view_state.gd")
const LaunchPayloadModel = preload("res://scripts/app/models/launch_payload.gd")
const SessionTransport = preload("res://scripts/app/session_transport.gd")

signal session_state_changed(state: StatusCardState)

enum SessionPhase {
    WAITING_FOR_LAUNCH,
    CONNECTING,
    RETRYING,
    AUTHENTICATING,
    JOINING,
    SYNCING,
    READY,
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
var _has_auth_ok: bool
var _has_join_accepted: bool
var _connect_attempts: int
var _retry_timer: Timer
var _session_transport: SessionTransport

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

func is_waiting_for_launch() -> bool:
    return _phase == SessionPhase.WAITING_FOR_LAUNCH

func _on_launch_payload_received(payload: LaunchPayloadModel) -> void:
    if _phase != SessionPhase.WAITING_FOR_LAUNCH and _phase != SessionPhase.FAILED:
        return

    _launch_payload = payload
    _current_player_id = ""
    _has_auth_ok = false
    _has_join_accepted = false
    _connect_attempts = 0
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
    if _try_schedule_retry("The multiplayer connection to the game server failed.") :
        return
    _fail_session("The multiplayer connection to the game server failed.")

func _on_server_disconnected() -> void:
    if _phase == SessionPhase.READY:
        return
    if _try_schedule_retry("The game server disconnected during session setup.") :
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
func rpc_join_accepted(_seq: int, player_id: String, _player_index: int, last_seq: int) -> void:
    assert(_launch_payload)
    if not _has_auth_ok:
        _fail_session("Received join success before auth completed.")
        return
    if player_id != _current_player_id:
        _fail_session("The server accepted a different player id than the one that authenticated.")
        return

    _has_join_accepted = true
    _update_state(
        SessionPhase.SYNCING,
        "Syncing session state",
        "Join succeeded. The client is requesting authoritative state starting from sequence %d." % last_seq,
        "This keeps the Godot client aligned with the existing reconnect and sync contract."
    )
    rpc_id(1, "rpc_sync_request", _launch_payload._game_id, player_id, last_seq)

@rpc("authority")
func rpc_action_rejected(_seq: int, reason: String) -> void:
    _fail_session("The game server rejected the session: %s" % reason)

@rpc("authority")
func rpc_sync_complete(_seq: int, _final_seq: int) -> void:
    if not _has_join_accepted:
        _fail_session("Received sync completion before join acceptance.")
        return

    _update_state(
        SessionPhase.READY,
        "Session ready",
        "The server handshake finished successfully and the client can enter the next player state.",
        "The next milestone can reuse this same path as the gate into waiting-room UI."
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
