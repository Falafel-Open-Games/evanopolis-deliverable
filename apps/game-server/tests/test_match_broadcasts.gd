extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_broadcast_sequence_is_monotonic() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")
    assert_eq(game_match.rpc_player_ready(config.game_id, "alice"), "", "alice ready accepted")
    assert_eq(game_match.rpc_player_ready(config.game_id, "bob"), "", "bob ready accepted")

    _assert_monotonic_sequences(client_a)
    _assert_monotonic_sequences(client_b)


func test_turn_started_matches_state_player_index() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")
    assert_eq(game_match.rpc_player_ready(config.game_id, "alice"), "", "alice ready accepted")
    assert_eq(game_match.rpc_player_ready(config.game_id, "bob"), "", "bob ready accepted")

    var turn_started: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turn_started.size(), 1, "turn started event emitted")
    assert_eq(int(turn_started[0].get("player_index", -1)), game_match.state.current_player_index, "turn index matches state")


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results


func _assert_monotonic_sequences(client: MatchTestClient) -> void:
    var last_seq: int = 0
    for event in client.events:
        var seq_value: int = int(event.get("seq", 0))
        if seq_value <= 0:
            continue
        assert_gt(seq_value, last_seq, "broadcast sequences are increasing")
        last_seq = seq_value
