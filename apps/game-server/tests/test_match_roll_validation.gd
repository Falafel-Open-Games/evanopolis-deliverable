extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const HeadlessServer = preload("res://scripts/server.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_roll_rejected_for_non_current_player() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")

    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "bob")
    var rejected: Array[Dictionary] = _filter_events(client_b, "rpc_action_rejected")
    assert_eq(rejected.size(), 1, "non-current player roll is rejected")
    assert_eq(str(rejected[0].get("reason", "")), "not_current_player", "rejection reason")


func test_roll_rejected_before_match_start() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var rejected: Array[Dictionary] = _filter_events(client_a, "rpc_action_rejected")
    assert_eq(rejected.size(), 1, "roll before match start is rejected")
    assert_eq(str(rejected[0].get("reason", "")), "match_not_started", "rejection reason")


func test_roll_rejects_invalid_game_id() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var result: Dictionary = server.rpc_roll_dice("missing_game", "alice")
    assert_eq(str(result.get("reason", "")), "invalid_game_id", "invalid game id roll is rejected")


func test_roll_rejects_unregistered_player_id() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)

    var roll_result: Dictionary = server.rpc_roll_dice("demo_002", "ghost", 10)
    assert_eq(str(roll_result.get("reason", "")), "unregistered_peer", "unknown peer is rejected")


func test_roll_rejects_peer_game_id_mismatch() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var config_other: Config = Config.new("res://configs/demo_003.toml")
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.create_match(config_other)
    server.peer_slots[7] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }

    var roll_result: Dictionary = server.rpc_roll_dice("demo_003", "alice", 7)
    assert_eq(str(roll_result.get("reason", "")), "peer_game_id_mismatch", "peer game id mismatch is rejected")


func test_roll_rejects_peer_player_mismatch() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[8] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }

    var roll_result: Dictionary = server.rpc_roll_dice("demo_002", "bob", 8)
    assert_eq(str(roll_result.get("reason", "")), "peer_player_mismatch", "peer player mismatch is rejected")


func test_roll_rejected_while_pending_action_required() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.rpc_roll_dice("demo_002", "alice")
    var rejected: Array[Dictionary] = _filter_events(client_a, "rpc_action_rejected")
    assert_true(rejected.size() > 0, "rejection event emitted for extra roll")
    var latest: Dictionary = rejected[rejected.size() - 1]
    assert_eq(str(latest.get("reason", "")), "pending_action_required", "roll blocked until pending action resolved")


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results
