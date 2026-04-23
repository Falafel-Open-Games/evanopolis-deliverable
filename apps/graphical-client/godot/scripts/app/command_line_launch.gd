extends RefCounted

const LaunchPayloadModel = preload("res://scripts/app/models/launch_payload.gd")

const ARGUMENT_NAME_TOKEN: String = "--token"
const ARGUMENT_NAME_GAME_ID: String = "--game-id"
const ARGUMENT_NAME_GAME_SERVER_URL: String = "--game-server-url"
const ARGUMENT_NAME_PLAYER_ADDRESS: String = "--player-address"

func resolve_boot_result() -> Dictionary:
    var arguments: PackedStringArray = OS.get_cmdline_args()
    var parsed_arguments: Dictionary = _parse_named_arguments(arguments)
    if parsed_arguments.is_empty():
        return {
            "kind": "error",
            "error_message": "This scene expects --token, --game-id, --game-server-url, and --player-address when run outside the web host bridge.",
        }

    var token: String = str(parsed_arguments.get(ARGUMENT_NAME_TOKEN, ""))
    var game_id: String = str(parsed_arguments.get(ARGUMENT_NAME_GAME_ID, ""))
    var game_server_url: String = str(parsed_arguments.get(ARGUMENT_NAME_GAME_SERVER_URL, ""))
    var player_address: String = str(parsed_arguments.get(ARGUMENT_NAME_PLAYER_ADDRESS, ""))
    var validation_error: String = _validate_launch_payload_fields(
        token,
        game_id,
        game_server_url,
        player_address
    )
    if validation_error != "":
        return {
            "kind": "error",
            "error_message": validation_error,
        }

    return {
        "kind": "payload",
        "payload": LaunchPayloadModel.new(token, game_id, game_server_url, player_address)
    }

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
