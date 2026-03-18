extends GutTest

const Config = preload("res://scripts/config.gd")
const HeadlessServer = preload("res://scripts/server.gd")
const RoomDefinitionLoader = preload("res://scripts/room_definition_loader.gd")


func test_config_load_from_dictionary_uses_experimental_board_size() -> void:
    var config: Config = Config.new("")
    config.load_from_dictionary(
        {
            "game_id": "room-123",
            "player_count": 4,
            "experimental": {
                "board_size": 30,
            },
        },
    )

    assert_eq(config.game_id, "room-123", "dictionary load keeps game id")
    assert_eq(config.player_count, 4, "dictionary load keeps player count")
    assert_eq(config.board_size, 30, "dictionary load uses experimental board size")


func test_config_load_from_dictionary_falls_back_to_default_board_size() -> void:
    var config: Config = Config.new("")
    config.load_from_dictionary(
        {
            "game_id": "room-123",
            "player_count": 2,
        },
    )

    assert_eq(config.board_size, Config.DEFAULT_BOARD_SIZE, "dictionary load falls back to default board size")


func test_room_definition_loader_creates_missing_match() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var reason: String = RoomDefinitionLoader.hydrate_match(
        server,
        "room-123",
        {
            "game_id": "room-123",
            "player_count": 3,
            "experimental": {
                "board_size": 30,
            },
            "created_at": "2026-03-17T12:00:00.000Z",
        },
        true,
    )

    assert_eq(reason, "", "valid room definition hydrates cleanly")
    assert_true(server.matches.has("room-123"), "server stores hydrated match")
    var game_match = server.matches.get("room-123")
    assert_eq(game_match.config.game_id, "room-123", "hydrated match keeps game id")
    assert_eq(game_match.config.player_count, 3, "hydrated match keeps player count")
    assert_eq(game_match.config.board_size, 30, "hydrated match keeps board size")
    assert_true(game_match.require_explicit_ready, "hydrated matches keep explicit ready flow")


func test_room_definition_loader_rejects_invalid_room_definition() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var reason: String = RoomDefinitionLoader.hydrate_match(
        server,
        "room-123",
        {
            "game_id": "",
            "player_count": 0,
        },
        true,
    )

    assert_eq(reason, "invalid_room_definition", "invalid room definition is rejected")
    assert_false(server.matches.has("room-123"), "invalid definition does not create a match")


func test_room_definition_loader_rejects_game_id_mismatch() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var reason: String = RoomDefinitionLoader.hydrate_match(
        server,
        "room-123",
        {
            "game_id": "room-999",
            "player_count": 2,
        },
        true,
    )

    assert_eq(reason, "invalid_room_definition", "mismatched room game id is rejected")
    assert_false(server.matches.has("room-123"), "mismatched definition does not create a match")
