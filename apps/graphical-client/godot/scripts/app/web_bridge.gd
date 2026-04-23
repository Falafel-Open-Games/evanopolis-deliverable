extends RefCounted

const LaunchPayloadModel = preload("res://scripts/app/models/launch_payload.gd")

signal launch_payload_received(payload: LaunchPayloadModel)
signal bridge_error(message: String)

enum MessageType {
    UNKNOWN = -1,
    CLIENT_READY,
    LAUNCH_PAYLOAD,
}

const PROTOCOL_NAME: String = "open-game-host"
const PROTOCOL_VERSION: int = 1

var _window: JavaScriptObject
var _json_interface: JavaScriptObject
var _message_callback: JavaScriptObject
var _expected_host_origin: String

func start() -> void:
    _window = JavaScriptBridge.get_interface("window")
    _json_interface = JavaScriptBridge.get_interface("JSON")
    assert(_window)
    assert(_json_interface)

    _message_callback = JavaScriptBridge.create_callback(_on_host_message)
    _window.addEventListener("message", _message_callback)
    _expected_host_origin = _detect_expected_host_origin()
    _post_client_ready()

func stop() -> void:
    if _window == null:
        return
    if _message_callback == null:
        return
    _window.removeEventListener("message", _message_callback)

func describe_expected_host() -> String:
    if _expected_host_origin == "":
        return "No referrer origin was detected, so the first valid open-game-host message will define the host origin for this session."
    return "Expected host origin: %s" % _expected_host_origin

func _post_client_ready() -> void:
    assert(_window)
    var message: Dictionary = {
        "protocol": PROTOCOL_NAME,
        "version": PROTOCOL_VERSION,
        "type": _message_type_to_wire(MessageType.CLIENT_READY),
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

    var message_type: int = _message_type_from_wire(str(message.get("type", "")))
    if message_type != MessageType.LAUNCH_PAYLOAD:
        return

    var payload_variant: Variant = message.get("payload", {})
    if not (payload_variant is Dictionary):
        bridge_error.emit("The wrapper sent a launch_payload message without a payload object.")
        return

    var payload_fields: Dictionary = payload_variant
    var token: String = str(payload_fields.get("token", ""))
    var game_id: String = str(payload_fields.get("gameId", ""))
    var game_server_url: String = str(payload_fields.get("gameServerUrl", ""))
    var player_address: String = str(payload_fields.get("playerAddress", ""))
    var validation_error: String = _validate_launch_payload_fields(
        token,
        game_id,
        game_server_url,
        player_address
    )
    if validation_error != "":
        bridge_error.emit(validation_error)
        return

    if _expected_host_origin == "" and event_origin != "":
        _expected_host_origin = event_origin

    launch_payload_received.emit(
        LaunchPayloadModel.new(token, game_id, game_server_url, player_address)
    )

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

func _message_type_to_wire(message_type: int) -> String:
    match message_type:
        MessageType.CLIENT_READY:
            return "client_ready"
        MessageType.LAUNCH_PAYLOAD:
            return "launch_payload"
        _:
            return ""

func _message_type_from_wire(message_type: String) -> int:
    match message_type:
        "client_ready":
            return MessageType.CLIENT_READY
        "launch_payload":
            return MessageType.LAUNCH_PAYLOAD
        _:
            return MessageType.UNKNOWN

func _validate_launch_payload_fields(
    token: String,
    game_id: String,
    game_server_url: String,
    player_address: String
) -> String:
    if token.strip_edges() == "":
        return "Required field `token` is missing."

    if game_id.strip_edges() == "":
        return "Required field `gameId` is missing."

    if game_server_url.strip_edges() == "":
        return "Required field `gameServerUrl` is missing."

    if player_address.strip_edges() == "":
        return "Required field `playerAddress` is missing."

    return ""

func _detect_expected_host_origin() -> String:
    var detected_origin: Variant = JavaScriptBridge.eval(
        "document.referrer ? new URL(document.referrer).origin : ''",
        true
    )
    return str(detected_origin)
