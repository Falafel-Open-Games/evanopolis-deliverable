extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_match_start_emits_game_started_after_all_players_ready() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    assert_eq(config.player_count, 2, "demo_002 expects two players")
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    _assert_player_joined_events(client_a, ["alice"])

    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")
    assert_eq(_filter_events(client_a, "rpc_game_started").size(), 0, "match should not start before ready barrier")

    assert_eq(game_match.rpc_player_ready(config.game_id, "alice"), "", "alice ready accepted")
    assert_eq(_filter_events(client_a, "rpc_game_started").size(), 0, "match should still wait for bob ready")
    assert_eq(game_match.rpc_player_ready(config.game_id, "bob"), "", "bob ready accepted")

    _assert_player_joined_events(client_a, ["alice", "bob"])
    _assert_game_start_events(
        _filter_events(client_a, "rpc_game_started"),
        _filter_events(client_a, "rpc_board_state"),
        _filter_events(client_a, "rpc_turn_started"),
        config.game_id,
        config.board_size,
    )
    _assert_game_start_events(
        _filter_events(client_b, "rpc_game_started"),
        _filter_events(client_b, "rpc_board_state"),
        _filter_events(client_b, "rpc_turn_started"),
        config.game_id,
        config.board_size,
    )


func test_join_broadcasts_player_joined() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")

    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    var joined_a: Array[Dictionary] = _filter_events(client_a, "rpc_player_joined")
    var joined_b: Array[Dictionary] = _filter_events(client_b, "rpc_player_joined")
    assert_eq(joined_a.size(), 2, "first client should see both join broadcasts")
    assert_eq(joined_b.size(), 1, "second client should see its own join broadcast")
    assert_eq(str(joined_a[0].get("player_id", "")), "alice", "first join is alice")
    assert_eq(str(joined_a[1].get("player_id", "")), "bob", "second join is bob")
    assert_eq(str(joined_b[0].get("player_id", "")), "bob", "second client receives bob join")


func test_join_replaces_duplicate_player_id() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")

    var result_b: Dictionary = game_match.assign_client("alice", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "duplicate player_id replaces connection")
    assert_eq(int(result_b.get("player_index", -1)), 0, "duplicate player_id keeps existing slot")
    assert_eq(game_match.clients[0], client_b, "duplicate player_id replaces client")


func test_join_rejects_when_match_full() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    var client_c: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")

    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    var result_c: Dictionary = game_match.assign_client("carol", client_c)
    assert_eq(str(result_c.get("reason", "")), "match_full", "extra client is rejected when match is full")


func test_rejects_invalid_player_id() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var result: Dictionary = game_match.assign_client("", client_a)
    assert_eq(str(result.get("reason", "")), "invalid_player_id", "empty player_id rejected")


func test_rejects_invalid_player_index() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var reason_negative: String = game_match.register_client_at_index("alice", -1, client_a)
    assert_eq(reason_negative, "invalid_player_index", "negative index rejected")
    var reason_large: String = game_match.register_client_at_index("alice", 99, client_a)
    assert_eq(reason_large, "invalid_player_index", "out-of-range index rejected")


func test_last_seq_progresses_on_join() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    assert_eq(game_match.last_sequence(), 1, "first join emits player joined")

    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")
    assert_eq(game_match.last_sequence(), 2, "second join emits player joined only")

    assert_eq(game_match.rpc_player_ready(config.game_id, "alice"), "", "alice ready accepted")
    assert_eq(game_match.last_sequence(), 3, "alice ready emits ready state")
    assert_eq(game_match.rpc_player_ready(config.game_id, "bob"), "", "bob ready accepted")
    assert_eq(game_match.last_sequence(), 7, "bob ready emits ready state and start events")


func test_three_player_match_starts_after_third_ready() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    config.game_id = "demo_003_three"
    config.player_count = 3
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    var client_c: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    assert_eq(_filter_events(client_a, "rpc_game_started").size(), 0, "no game start after first join")

    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")
    assert_eq(_filter_events(client_a, "rpc_game_started").size(), 0, "no game start after second join")
    assert_eq(_filter_events(client_b, "rpc_game_started").size(), 0, "no game start after second join for second client")

    var result_c: Dictionary = game_match.assign_client("carol", client_c)
    assert_eq(str(result_c.get("reason", "")), "", "third client should register")

    var started_a: Array[Dictionary] = _filter_events(client_a, "rpc_game_started")
    var started_b: Array[Dictionary] = _filter_events(client_b, "rpc_game_started")
    var started_c: Array[Dictionary] = _filter_events(client_c, "rpc_game_started")
    assert_eq(started_a.size(), 0, "no game start before ready calls")
    assert_eq(started_b.size(), 0, "no game start before ready calls")
    assert_eq(started_c.size(), 0, "no game start before ready calls")

    assert_eq(game_match.rpc_player_ready(config.game_id, "alice"), "", "alice ready accepted")
    assert_eq(game_match.rpc_player_ready(config.game_id, "bob"), "", "bob ready accepted")
    assert_eq(_filter_events(client_a, "rpc_game_started").size(), 0, "still waiting for third ready")
    assert_eq(game_match.rpc_player_ready(config.game_id, "carol"), "", "carol ready accepted")

    started_a = _filter_events(client_a, "rpc_game_started")
    started_b = _filter_events(client_b, "rpc_game_started")
    started_c = _filter_events(client_c, "rpc_game_started")
    assert_eq(started_a.size(), 1, "game started after third ready")
    assert_eq(started_b.size(), 1, "game started after third ready for second client")
    assert_eq(started_c.size(), 1, "game started after third ready for third client")
    assert_eq(int(started_a[0].get("seq", -1)), 7, "game started seq after three joins + three readies")


func test_match_full_rejected_via_server_registration() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client registers")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client registers")

    var client_c: MatchTestClient = MatchTestClient.new()
    var result_c: Dictionary = game_match.assign_client("carol", client_c)
    assert_eq(str(result_c.get("reason", "")), "match_full", "extra client rejected")


func test_game_start_emitted_once_after_full() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [], true)
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    var client_c: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")
    assert_eq(game_match.rpc_player_ready(config.game_id, "alice"), "", "alice ready accepted")
    assert_eq(game_match.rpc_player_ready(config.game_id, "bob"), "", "bob ready accepted")

    var started_before: int = _filter_events(client_a, "rpc_game_started").size()
    var result_c: Dictionary = game_match.assign_client("carol", client_c)
    assert_eq(str(result_c.get("reason", "")), "match_full", "extra join rejected")
    var started_after: int = _filter_events(client_a, "rpc_game_started").size()
    assert_eq(started_before, started_after, "game start not emitted again")


func _assert_game_start_events(
        game_started: Array[Dictionary],
        board_state: Array[Dictionary],
        turn_started: Array[Dictionary],
        game_id: String,
        board_size: int,
) -> void:
    assert_eq(game_started.size(), 1, "expected one game started event")
    assert_eq(board_state.size(), 1, "expected one board state event")
    assert_eq(turn_started.size(), 1, "expected one turn started event")
    var first: Dictionary = game_started[0]
    assert_eq(str(first.get("game_id", "")), game_id, "game id propagated")
    var board_event: Dictionary = board_state[0]
    var board_payload: Dictionary = board_event.get("board", { })
    assert_eq(int(board_payload.get("size", -1)), board_size, "board size propagated")
    var second: Dictionary = turn_started[0]
    assert_eq(int(second.get("player_index", -1)), 0, "first turn player index")
    assert_eq(int(second.get("turn_number", -1)), 1, "turn number")
    assert_eq(int(second.get("cycle", -1)), 1, "cycle number")


func _assert_player_joined_events(client: MatchTestClient, expected_ids: Array[String]) -> void:
    var joined: Array[Dictionary] = _filter_events(client, "rpc_player_joined")
    assert_eq(joined.size(), expected_ids.size(), "player joined count")
    for index in range(expected_ids.size()):
        var event: Dictionary = joined[index]
        assert_eq(str(event.get("player_id", "")), expected_ids[index], "player joined id")


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results
