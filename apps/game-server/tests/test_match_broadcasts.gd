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


func test_identity_broadcast_and_color_conflict_are_handled() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "alice registers")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "bob registers")

    assert_eq(game_match.rpc_set_player_identity(config.game_id, "alice", "Miner Alice", 3, 1), "", "alice identity accepted")
    assert_eq(game_match.rpc_set_player_identity(config.game_id, "bob", "Miner Bob", 3, 2), "", "bob can reuse icon")
    assert_eq(game_match.rpc_set_player_identity(config.game_id, "bob", "Miner Bob", 4, 1), "color_unavailable", "bob cannot take alice color")

    var identity_events_a: Array[Dictionary] = _filter_events(client_a, "rpc_player_identity_changed")
    var identity_events_b: Array[Dictionary] = _filter_events(client_b, "rpc_player_identity_changed")
    assert_eq(identity_events_a.size(), 2, "alice sees both accepted identity updates")
    assert_eq(identity_events_b.size(), 2, "bob sees both accepted identity updates")

    assert_eq(str(identity_events_a[0].get("display_name", "")), "Miner Alice", "alice name broadcast")
    assert_eq(int(identity_events_a[0].get("icon_id", -1)), 3, "alice icon broadcast")
    assert_eq(int(identity_events_a[0].get("color_id", -1)), 1, "alice color broadcast")
    assert_eq(str(identity_events_a[1].get("display_name", "")), "Miner Bob", "bob name broadcast")
    assert_eq(int(identity_events_a[1].get("icon_id", -1)), 3, "bob can reuse alice icon")
    assert_eq(int(identity_events_a[1].get("color_id", -1)), 2, "bob color broadcast")

    _assert_monotonic_sequences(client_a)
    _assert_monotonic_sequences(client_b)


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
