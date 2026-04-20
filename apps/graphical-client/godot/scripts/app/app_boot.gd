extends Node

## Boot entrypoint for the web client.
##
## In web exports this scene:
## - sends `client_ready` to the parent iframe host
## - waits for `launch_payload` or `launch_missing`
## - validates the launch payload
## - shows a minimal boot state without rendering the raw token
##
## In editor or native runs this scene can also read launch context from:
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

const PROTOCOL_NAME: String = "open-game-host"
const PROTOCOL_VERSION: int = 1
const MESSAGE_TYPE_CLIENT_READY: String = "client_ready"
const MESSAGE_TYPE_LAUNCH_PAYLOAD: String = "launch_payload"
const MESSAGE_TYPE_LAUNCH_MISSING: String = "launch_missing"
const BRIDGE_TIMEOUT_SECONDS: float = 8.0
const ARGUMENT_NAME_TOKEN: String = "--token"
const ARGUMENT_NAME_GAME_ID: String = "--game-id"
const ARGUMENT_NAME_GAME_SERVER_URL: String = "--game-server-url"
const ARGUMENT_NAME_PLAYER_ADDRESS: String = "--player-address"

@onready var status_label: Label = %StatusLabel
@onready var detail_label: Label = %DetailLabel
@onready var note_label: Label = %NoteLabel
@onready var bridge_timeout_timer: Timer = %BridgeTimeoutTimer

var _window: JavaScriptObject = null
var _json_interface: JavaScriptObject = null
var _message_callback: JavaScriptObject = null
var _launch_payload: Dictionary = {}
var _expected_host_origin: String = ""
var _launch_payload_received: bool = false

func _ready() -> void:
    assert(status_label)
    assert(detail_label)
    assert(note_label)
    assert(bridge_timeout_timer)

    bridge_timeout_timer.timeout.connect(_on_bridge_timeout)

    if not OS.has_feature("web"):
        if _try_command_line_launch_payload():
            return
        _show_local_editor_state()
        return

    _setup_web_bridge()

func _exit_tree() -> void:
    if _window == null:
        return
    if _message_callback == null:
        return
    _window.removeEventListener("message", _message_callback)

func _setup_web_bridge() -> void:
    _window = JavaScriptBridge.get_interface("window")
    _json_interface = JavaScriptBridge.get_interface("JSON")
    assert(_window)
    assert(_json_interface)

    _message_callback = JavaScriptBridge.create_callback(_on_host_message)
    _window.addEventListener("message", _message_callback)
    _expected_host_origin = _detect_expected_host_origin()

    _set_boot_state(
        "Waiting for wrapper host",
        "The web client is loaded and waiting for the parent launch page to send launch data through the open-game-host bridge.",
        _describe_expected_host()
    )

    bridge_timeout_timer.start(BRIDGE_TIMEOUT_SECONDS)
    _post_client_ready()

func _show_local_editor_state() -> void:
    _set_boot_state(
        "Local editor boot",
        "This scene is not running inside a web export, so the host bridge is disabled. Use this mode for layout work and local tweaks.",
        "To simulate launch data in the editor, add --token, --game-id, --game-server-url, and --player-address in the run arguments."
    )

func _post_client_ready() -> void:
    assert(_window)
    var message: Dictionary = {
        "protocol": PROTOCOL_NAME,
        "version": PROTOCOL_VERSION,
        "type": MESSAGE_TYPE_CLIENT_READY,
    }
    var serialized_message: String = JSON.stringify(message)
    _window.parent.postMessage(serialized_message, "*")

func _on_host_message(arguments: Array) -> void:
    if arguments.is_empty():
        return

    var event: Variant = arguments[0]
    if event == null:
        return

    var event_origin: String = str(event.origin)
    if _expected_host_origin != "" and event_origin != _expected_host_origin:
        return

    var message: Dictionary = _parse_host_message(event.data)
    if message.is_empty():
        return

    if str(message.get("protocol", "")) != PROTOCOL_NAME:
        return
    if int(message.get("version", -1)) != PROTOCOL_VERSION:
        return

    var message_type: String = str(message.get("type", ""))
    if message_type == MESSAGE_TYPE_LAUNCH_PAYLOAD:
        _handle_launch_payload(message, event_origin)
        return
    if message_type == MESSAGE_TYPE_LAUNCH_MISSING:
        _handle_launch_missing(message, event_origin)

func _parse_host_message(raw_message: Variant) -> Dictionary:
    if raw_message is Dictionary:
        return raw_message

    if raw_message is String:
        var parsed_message: Variant = JSON.parse_string(raw_message)
        if parsed_message is Dictionary:
            return parsed_message
        return {}

    if _json_interface == null:
        return {}

    var serialized_message: String = str(_json_interface.stringify(raw_message))
    var parsed_variant: Variant = JSON.parse_string(serialized_message)
    if parsed_variant is Dictionary:
        return parsed_variant

    return {}

func _handle_launch_payload(message: Dictionary, event_origin: String) -> void:
    if _launch_payload_received:
        return

    var payload_variant: Variant = message.get("payload", {})
    if not (payload_variant is Dictionary):
        _show_error_state(
            "Invalid launch payload",
            "The wrapper sent a launch_payload message without a payload object."
        )
        return

    var payload: Dictionary = payload_variant
    var validation_error: String = _validate_launch_payload(payload)
    if validation_error != "":
        _show_error_state("Invalid launch payload", validation_error)
        return

    if _expected_host_origin == "" and event_origin != "":
        _expected_host_origin = event_origin

    _launch_payload_received = true
    _launch_payload = payload
    bridge_timeout_timer.stop()

    _set_boot_state(
        "Launch data received",
        _build_launch_payload_summary(payload),
        "The next milestone will replace this confirmation view with real server connection, auth, and match entry."
    )

func _try_command_line_launch_payload() -> bool:
    var payload: Dictionary = _build_launch_payload_from_command_line()
    if payload.is_empty():
        return false

    var validation_error: String = _validate_launch_payload(payload)
    if validation_error != "":
        _show_error_state("Invalid launch arguments", validation_error)
        return true

    _launch_payload_received = true
    _launch_payload = payload

    _set_boot_state(
        "Launch arguments received",
        _build_launch_payload_summary(payload),
        "This launch context came from editor or native run arguments instead of the web host bridge."
    )
    return true

func _build_launch_payload_from_command_line() -> Dictionary:
    var arguments: PackedStringArray = _collect_command_line_arguments()
    if arguments.is_empty():
        return {}

    var parsed_arguments: Dictionary = _parse_named_arguments(arguments)
    if parsed_arguments.is_empty():
        return {}

    return {
        "token": str(parsed_arguments.get(ARGUMENT_NAME_TOKEN, "")),
        "gameId": str(parsed_arguments.get(ARGUMENT_NAME_GAME_ID, "")),
        "gameServerUrl": str(parsed_arguments.get(ARGUMENT_NAME_GAME_SERVER_URL, "")),
        "playerAddress": str(parsed_arguments.get(ARGUMENT_NAME_PLAYER_ADDRESS, "")),
    }

func _collect_command_line_arguments() -> PackedStringArray:
    var combined_arguments: PackedStringArray = []
    var user_arguments: PackedStringArray = OS.get_cmdline_user_args()
    var engine_arguments: PackedStringArray = OS.get_cmdline_args()

    for argument: String in user_arguments:
        combined_arguments.append(argument)
    for argument: String in engine_arguments:
        combined_arguments.append(argument)

    return combined_arguments

func _parse_named_arguments(arguments: PackedStringArray) -> Dictionary:
    var parsed_arguments: Dictionary = {}
    var index: int = 0

    while index < arguments.size():
        var argument: String = arguments[index]
        var equals_index: int = argument.find("=")

        if equals_index > 0:
            var key: String = argument.substr(0, equals_index)
            var value: String = argument.substr(equals_index + 1)
            if _is_supported_launch_argument(key):
                parsed_arguments[key] = value
            index += 1
            continue

        if _is_supported_launch_argument(argument):
            var next_index: int = index + 1
            if next_index < arguments.size():
                parsed_arguments[argument] = arguments[next_index]
                index += 2
                continue
            parsed_arguments[argument] = ""
        index += 1

    return parsed_arguments

func _is_supported_launch_argument(argument: String) -> bool:
    return argument in [
        ARGUMENT_NAME_TOKEN,
        ARGUMENT_NAME_GAME_ID,
        ARGUMENT_NAME_GAME_SERVER_URL,
        ARGUMENT_NAME_PLAYER_ADDRESS,
    ]

func _handle_launch_missing(message: Dictionary, event_origin: String) -> void:
    if _expected_host_origin == "" and event_origin != "":
        _expected_host_origin = event_origin

    bridge_timeout_timer.stop()

    var reason: String = str(message.get("reason", "missing_launch_payload"))
    _show_error_state(
        "Launch payload missing",
        "The wrapper reported that no launch payload is available. Launch the match again from the wrapper. Reason: %s." % reason
    )

func _validate_launch_payload(payload: Dictionary) -> String:
    var token: String = str(payload.get("token", ""))
    if token.strip_edges() == "":
        return "Required field `token` is missing."

    var game_id: String = str(payload.get("gameId", ""))
    if game_id.strip_edges() == "":
        return "Required field `gameId` is missing."

    var game_server_url: String = str(payload.get("gameServerUrl", ""))
    if game_server_url.strip_edges() == "":
        return "Required field `gameServerUrl` is missing."

    var player_address: String = str(payload.get("playerAddress", ""))
    if player_address.strip_edges() == "":
        return "Required field `playerAddress` is missing."

    return ""

func _build_launch_payload_summary(payload: Dictionary) -> String:
    var game_id: String = str(payload.get("gameId", ""))
    var game_server_url: String = str(payload.get("gameServerUrl", ""))
    var player_address: String = str(payload.get("playerAddress", ""))
    var token: String = str(payload.get("token", ""))

    return "\n".join([
        "Room: %s" % game_id,
        "Server: %s" % game_server_url,
        "Player: %s" % player_address,
        "Token: %s" % _mask_token_presence(token),
    ])

func _mask_token_presence(token: String) -> String:
    if token.strip_edges() == "":
        return "missing"
    return "present (%d chars)" % token.length()

func _on_bridge_timeout() -> void:
    if _launch_payload_received:
        return

    _show_error_state(
        "Host handshake timed out",
        "No open-game-host launch message arrived within %.0f seconds. Confirm that the wrapper launch page is embedding the web export and sending launch_payload." % BRIDGE_TIMEOUT_SECONDS
    )

func _detect_expected_host_origin() -> String:
    var detected_origin: Variant = JavaScriptBridge.eval(
        "document.referrer ? new URL(document.referrer).origin : ''",
        true
    )
    return str(detected_origin)

func _describe_expected_host() -> String:
    if _expected_host_origin == "":
        return "No referrer origin was detected, so the first valid open-game-host message will define the host origin for this session."
    return "Expected host origin: %s" % _expected_host_origin

func _show_error_state(title: String, message: String) -> void:
    _set_boot_state(title, message, "This scene is still only the boot bridge. It will not continue into gameplay until the launch contract is satisfied.")

func _set_boot_state(status_text: String, detail_text: String, note_text: String) -> void:
    status_label.text = status_text
    detail_label.text = detail_text
    note_label.text = note_text
