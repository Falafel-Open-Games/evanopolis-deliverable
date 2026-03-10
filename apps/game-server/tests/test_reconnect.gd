extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_match_allows_reconnect_with_same_player_id() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first join should succeed")
    assert_eq(int(result_a.get("player_index", -1)), 0, "first join gets slot 0")

    var result_b: Dictionary = game_match.assign_client("alice", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "reconnect should be allowed")
    assert_eq(int(result_b.get("player_index", -1)), 0, "reconnect keeps same slot")
    assert_eq(game_match.clients[0], client_b, "reconnect should replace client in slot")


func test_match_allows_reconnect_when_match_full() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    var client_c: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first join should succeed")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second join should succeed")

    var result_c: Dictionary = game_match.assign_client("alice", client_c)
    assert_eq(str(result_c.get("reason", "")), "", "reconnect should be allowed even when full")
    assert_eq(int(result_c.get("player_index", -1)), 0, "reconnect keeps same slot")
    assert_eq(game_match.clients[0], client_c, "reconnect should replace client in slot")
