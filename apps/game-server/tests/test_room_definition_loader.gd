extends GutTest

const Config = preload("res://scripts/config.gd")
const HeadlessServer = preload("res://scripts/server.gd")
const MatchPersistence = preload("res://scripts/match_persistence.gd")
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


func test_room_definition_loader_restores_persisted_match_state_after_restart() -> void:
    var persistence_root: String = "user://test_match_state_restore_room_loader"
    _clear_persistence_root(persistence_root)
    var room_definition: Dictionary = {
        "game_id": "room-123",
        "player_count": 2,
        "experimental": {
            "board_size": 24,
        },
    }

    var initial_server: HeadlessServer = HeadlessServer.new()
    initial_server.match_persistence = MatchPersistence.new(persistence_root)
    var initial_config: Config = Config.new("")
    initial_config.load_from_dictionary(room_definition)
    initial_server.create_match(initial_config, true)
    initial_server.authorize_peer(11, "alice")
    initial_server.authorize_peer(12, "bob")
    assert_eq(str(initial_server.register_remote_client("room-123", "alice", 11, null).get("reason", "")), "", "alice joins initial match")
    assert_eq(str(initial_server.register_remote_client("room-123", "bob", 12, null).get("reason", "")), "", "bob joins initial match")
    assert_eq(str(initial_server.rpc_set_player_identity("room-123", "alice", "Miner Alice", 3, 3, 11).get("reason", "")), "", "alice identity persisted")
    assert_eq(str(initial_server.rpc_set_player_identity("room-123", "bob", "Miner Bob", 4, 2, 12).get("reason", "")), "", "bob identity persisted")
    assert_eq(str(initial_server.rpc_player_ready("room-123", "alice", 11).get("reason", "")), "", "alice ready persisted")
    assert_eq(str(initial_server.rpc_player_ready("room-123", "bob", 12).get("reason", "")), "", "bob ready persisted")
    assert_eq(str(initial_server.rpc_roll_dice("room-123", "alice", 11).get("reason", "")), "", "started match state persisted")

    var restarted_server: HeadlessServer = HeadlessServer.new()
    restarted_server.match_persistence = MatchPersistence.new(persistence_root)
    var reason: String = RoomDefinitionLoader.hydrate_match(
        restarted_server,
        "room-123",
        room_definition,
        true,
    )

    assert_eq(reason, "", "hydrating after restart should restore persisted state")
    assert_true(restarted_server.matches.has("room-123"), "restarted server restores match")
    var restarted_match = restarted_server.matches.get("room-123")
    assert_true(restarted_match.has_started, "restored match keeps started state")
    assert_eq(str(restarted_match.player_ids[0]), "alice", "restored match keeps alice seat")
    assert_eq(str(restarted_match.player_ids[1]), "bob", "restored match keeps bob seat")
    assert_eq(str(restarted_match.state.players[0].display_name), "Miner Alice", "restored match keeps alice identity")
    assert_eq(str(restarted_match.state.players[1].display_name), "Miner Bob", "restored match keeps bob identity")
    assert_true(bool(restarted_match.player_ready[0]), "restored match keeps alice ready state")
    assert_true(bool(restarted_match.player_ready[1]), "restored match keeps bob ready state")
    assert_true(int(restarted_match.state.players[0].position) > 0, "restored match keeps pawn progress")

    restarted_server.authorize_peer(21, "alice")
    var reconnect_result: Dictionary = restarted_server.register_remote_client("room-123", "alice", 21, null)
    assert_eq(str(reconnect_result.get("reason", "")), "", "alice reconnects into restored match")
    assert_eq(int(reconnect_result.get("player_index", -1)), 0, "alice reconnect keeps original slot")

    var sync_result: Dictionary = restarted_server.rpc_sync_request("room-123", "alice", 21)
    assert_eq(str(sync_result.get("reason", "")), "", "sync works after restore")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    assert_true(bool(snapshot.get("has_started", false)), "restored snapshot reports started match")
    var players: Array = snapshot.get("players", [])
    assert_eq(players.size(), 2, "restored snapshot keeps both seats")
    if players.size() == 2:
        var alice: Dictionary = players[0]
        var bob: Dictionary = players[1]
        assert_eq(str(alice.get("display_name", "")), "Miner Alice", "restored snapshot keeps alice name")
        assert_eq(int(alice.get("icon_id", -1)), 3, "restored snapshot keeps alice icon")
        assert_eq(int(alice.get("color_id", -1)), 3, "restored snapshot keeps alice color")
        assert_eq(str(bob.get("display_name", "")), "Miner Bob", "restored snapshot keeps bob name")
        assert_eq(int(bob.get("icon_id", -1)), 4, "restored snapshot keeps bob icon")
        assert_eq(int(bob.get("color_id", -1)), 2, "restored snapshot keeps bob color")

    _clear_persistence_root(persistence_root)


func _clear_persistence_root(root_path: String) -> void:
    var global_root: String = ProjectSettings.globalize_path(root_path)
    var dir: DirAccess = DirAccess.open(global_root)
    if dir == null:
        return
    dir.list_dir_begin()
    while true:
        var entry: String = dir.get_next()
        if entry.is_empty():
            break
        if entry == "." or entry == "..":
            continue
        DirAccess.remove_absolute(global_root.path_join(entry))
    dir.list_dir_end()
    DirAccess.remove_absolute(global_root)
