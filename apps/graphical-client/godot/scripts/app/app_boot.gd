extends Node
class_name AppBoot

## Boot entrypoint for the web client.
##
## This controller does not own presentation. It publishes boot progress through
## signals so a scene can attach any UI it wants, or no UI at all.
##
## In web exports this scene:
## - sends `client_ready` to the parent iframe host
## - waits for `launch_payload`
## - validates the launch payload
## - emits structured boot-state updates
##
## In editor or native runs this scene expects launch context from:
## - `--token`
## - `--game-id`
## - `--game-server-url`
## - `--player-address`
##
## Message envelope:
## - protocol: `open-game-host`
## - version: `1`
##
## Expected `launch_payload` fields:
## - `token`
## - `gameId`
## - `gameServerUrl`
## - `playerAddress`

const StatusCardState = preload("res://scripts/app/models/status_view_state.gd")
const LaunchPayloadModel = preload("res://scripts/app/models/launch_payload.gd")
const CommandLineLaunch = preload("res://scripts/app/command_line_launch.gd")
const WebBridge = preload("res://scripts/app/web_bridge.gd")

signal boot_state_changed(state: StatusCardState)
signal launch_payload_received(payload: LaunchPayloadModel)
const BRIDGE_TIMEOUT_SECONDS: float = 8.0

var _web_bridge: WebBridge
var _command_line_launch: CommandLineLaunch
var _launch_payload: LaunchPayloadModel
var _boot_state: StatusCardState = StatusCardState.new(
    "Booting",
    "Preparing boot scene...",
    "This scene documents the launch bridge and will become the first boot handoff into match flow."
)
var _launch_payload_received: bool = false
var _pending_launch_payload_emit: bool = false

@onready var bridge_timeout_timer: Timer = %BridgeTimeoutTimer

func _ready() -> void:
    assert(bridge_timeout_timer)

    bridge_timeout_timer.timeout.connect(_on_bridge_timeout)
    _command_line_launch = CommandLineLaunch.new()

    if not OS.has_feature("web"):
        _start_local_boot()
        return

    _start_web_bridge()

func _exit_tree() -> void:
    if _web_bridge == null:
        return
    _web_bridge.stop()

func get_boot_state() -> StatusCardState:
    return _boot_state.clone()

func get_launch_payload() -> LaunchPayloadModel:
    if _launch_payload == null:
        return null
    return _launch_payload.clone()

func _start_web_bridge() -> void:
    _web_bridge = WebBridge.new()
    _web_bridge.connect("bridge_error", Callable(self, "_on_web_bridge_error"))
    _web_bridge.connect("launch_payload_received", Callable(self, "_on_web_bridge_launch_payload_received"))
    _web_bridge.start()

    _set_boot_state(
        "Waiting for wrapper host",
        "The web client is loaded and waiting for the parent launch page to send launch data through the open-game-host bridge.",
        _web_bridge.describe_expected_host()
    )

    bridge_timeout_timer.start(BRIDGE_TIMEOUT_SECONDS)

func _start_local_boot() -> void:
    var command_line_resolution: Dictionary = _command_line_launch.resolve_boot_result()
    var kind: String = str(command_line_resolution.get("kind", "missing"))
    if kind == "error":
        _show_error_state("Invalid launch arguments", str(command_line_resolution.get("error_message", "")))
        return
    if kind == "payload":
        var command_line_payload: Variant = command_line_resolution.get("payload")
        assert(command_line_payload is LaunchPayloadModel)
        _accept_launch_payload(
            command_line_payload,
            "Launch arguments received",
            "This launch context came from editor or native run arguments instead of the web host bridge."
        )
        return

func _accept_launch_payload(
    payload: LaunchPayloadModel,
    status_text: String,
    note_text: String
) -> void:
    if _launch_payload_received:
        return

    _launch_payload_received = true
    _launch_payload = payload
    bridge_timeout_timer.stop()
    _pending_launch_payload_emit = true
    call_deferred("_emit_launch_payload_received")

    _set_boot_state(status_text, payload.build_summary(), note_text)

func _emit_launch_payload_received() -> void:
    assert(_pending_launch_payload_emit)
    _pending_launch_payload_emit = false
    launch_payload_received.emit(get_launch_payload())

func _on_web_bridge_error(message: String) -> void:
    _show_error_state("Invalid launch payload", message)

func _on_bridge_timeout() -> void:
    if _launch_payload_received:
        return

    _show_error_state(
        "Host handshake timed out",
        "No open-game-host launch message arrived within %.0f seconds. Confirm that the wrapper launch page is embedding the web export and sending launch_payload." % BRIDGE_TIMEOUT_SECONDS
    )

func _on_web_bridge_launch_payload_received(payload: LaunchPayloadModel) -> void:
    _accept_launch_payload(
        payload,
        "Launch data received",
        "The next milestone will replace this confirmation view with real server connection, auth, and match entry."
    )

func _show_error_state(title: String, message: String) -> void:
    _set_boot_state(
        title,
        message,
        "This scene is still only the boot bridge. It will not continue into gameplay until the launch contract is satisfied."
    )

func _set_boot_state(
    status_text: String,
    detail_text: String,
    note_text: String
) -> void:
    _boot_state = StatusCardState.new(status_text, detail_text, note_text)
    boot_state_changed.emit(get_boot_state())
