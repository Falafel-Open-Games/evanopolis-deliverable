class_name RoomDefinitionLoader
extends RefCounted

const Config = preload("res://scripts/config.gd")


static func hydrate_match(
        server: HeadlessServer,
        requested_game_id: String,
        room_definition: Dictionary,
        require_explicit_ready: bool = true,
) -> String:
    if server.matches.has(requested_game_id):
        return ""
    if room_definition.is_empty():
        return "invalid_game_id"
    var config: Config = Config.new("")
    config.load_from_dictionary(room_definition)
    if config.game_id.is_empty() or config.game_id != requested_game_id or config.player_count <= 0:
        return "invalid_room_definition"
    if server.matches.has(config.game_id):
        return ""
    server.create_match(config, require_explicit_ready)
    return ""
