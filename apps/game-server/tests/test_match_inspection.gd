extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_landing_on_inspection_marks_player_and_emits_event() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match._server_move_pawn(12)

    assert_true(game_match.state.players[0].in_inspection, "landing on inspection should set in_inspection")
    var sent_to_inspection: Array[Dictionary] = _filter_events(client_a, "rpc_player_sent_to_inspection")
    assert_eq(sent_to_inspection.size(), 1, "inspection landing should emit one inspection mutation event")
    if sent_to_inspection.size() == 1:
        assert_eq(str(sent_to_inspection[0].get("reason", "")), "tile_inspection", "inspection reason")


func test_inspection_player_cannot_roll_until_resolved() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].in_inspection = true
    game_match.rpc_roll_dice("demo_002", "alice")

    var rejected: Array[Dictionary] = _filter_events(client_a, "rpc_action_rejected")
    assert_eq(rejected.size(), 1, "roll should be rejected while player is in inspection")
    if rejected.size() == 1:
        assert_eq(str(rejected[0].get("reason", "")), "inspection_resolution_required", "inspection rejection reason")


func test_pay_inspection_fee_clears_inspection_and_allows_roll() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].in_inspection = true
    var pay_reason: String = game_match.rpc_pay_inspection_fee("demo_002", "alice")
    assert_eq(pay_reason, "", "pay inspection fee should succeed")
    assert_eq(game_match.state.players[0].in_inspection, false, "inspection should be cleared")
    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 118.0), "inspection fee deducted from fiat")

    var balance_changed: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    assert_eq(balance_changed.size(), 1, "paying inspection fee emits one balance change")
    if balance_changed.size() == 1:
        assert_true(is_equal_approx(float(balance_changed[0].get("fiat_delta", 0.0)), -2.0), "inspection fee fiat delta")
        assert_eq(str(balance_changed[0].get("reason", "")), "inspection_fee_paid", "inspection fee reason")

    game_match.rpc_roll_dice("demo_002", "alice")
    var rolls: Array[Dictionary] = _filter_events(client_a, "rpc_dice_rolled")
    assert_eq(rolls.size(), 1, "player can roll after paying inspection fee")


func test_pay_inspection_fee_rejected_when_not_in_inspection() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var pay_reason: String = game_match.rpc_pay_inspection_fee("demo_002", "alice")
    assert_eq(pay_reason, "not_in_inspection", "cannot pay inspection fee when not in inspection")


func test_use_inspection_voucher_clears_inspection_and_allows_roll() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].in_inspection = true
    game_match.state.players[0].inspection_free_exits = 1
    var voucher_reason: String = game_match.rpc_use_inspection_voucher("demo_002", "alice")
    assert_eq(voucher_reason, "", "using inspection voucher should succeed")
    assert_eq(game_match.state.players[0].in_inspection, false, "inspection cleared by voucher")
    assert_eq(game_match.state.players[0].inspection_free_exits, 0, "inspection voucher consumed")

    var balance_changed: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    assert_eq(balance_changed.size(), 1, "voucher use emits one balance event")
    if balance_changed.size() == 1:
        assert_eq(str(balance_changed[0].get("reason", "")), "inspection_voucher_used", "voucher use reason")
        assert_true(is_equal_approx(float(balance_changed[0].get("fiat_delta", 1.0)), 0.0), "voucher use has no fiat delta")
        assert_true(is_equal_approx(float(balance_changed[0].get("btc_delta", 1.0)), 0.0), "voucher use has no btc delta")

    game_match.rpc_roll_dice("demo_002", "alice")
    var rolls: Array[Dictionary] = _filter_events(client_a, "rpc_dice_rolled")
    assert_eq(rolls.size(), 1, "player can roll after using inspection voucher")


func test_use_inspection_voucher_rejected_without_vouchers() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].in_inspection = true
    game_match.state.players[0].inspection_free_exits = 0
    var voucher_reason: String = game_match.rpc_use_inspection_voucher("demo_002", "alice")
    assert_eq(voucher_reason, "no_inspection_voucher", "using inspection voucher requires available vouchers")


func test_roll_inspection_exit_with_doubles_clears_and_moves() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].in_inspection = true
    game_match.rng.seed = _find_seed_for_doubles(true)
    var reason: String = game_match.rpc_roll_inspection_exit("demo_002", "alice")
    assert_eq(reason, "", "inspection exit roll should succeed")
    assert_eq(game_match.state.players[0].in_inspection, false, "inspection cleared on doubles")

    var rolls: Array[Dictionary] = _filter_events(client_a, "rpc_dice_rolled")
    assert_eq(rolls.size(), 1, "inspection exit roll emits one dice event")
    var moved: Array[Dictionary] = _filter_events(client_a, "rpc_pawn_moved")
    assert_eq(moved.size(), 1, "doubles inspection exit moves pawn")
    var released: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    assert_eq(released.size(), 1, "doubles inspection exit emits one release mutation event")
    if released.size() == 1:
        assert_eq(str(released[0].get("reason", "")), "inspection_exit_doubles", "release reason on doubles")


func test_roll_inspection_exit_without_doubles_advances_turn_and_stays_inspected() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].in_inspection = true
    game_match.rng.seed = _find_seed_for_doubles(false)
    var reason: String = game_match.rpc_roll_inspection_exit("demo_002", "alice")
    assert_eq(reason, "", "inspection exit roll should run")
    assert_eq(game_match.state.players[0].in_inspection, true, "player remains inspected when roll is not doubles")

    var rolls: Array[Dictionary] = _filter_events(client_a, "rpc_dice_rolled")
    assert_eq(rolls.size(), 1, "inspection exit roll emits one dice event")
    var moved: Array[Dictionary] = _filter_events(client_a, "rpc_pawn_moved")
    assert_eq(moved.size(), 0, "failed inspection exit does not move pawn")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "failed inspection exit advances to next player")
    if turns.size() == 2:
        assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advances after failed inspection exit")


func test_snapshot_reflects_inspection_status_after_bear_inspection_card() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.bear_card_cursor = 2
    game_match._server_move_pawn(4)

    assert_true(game_match.state.players[0].in_inspection, "current player set to inspection after bear inspection card")
    var snapshot: Dictionary = game_match.build_state_snapshot()
    var players: Array = snapshot.get("players", [])
    assert_eq(players.size(), 2, "snapshot keeps two players")
    if players.size() == 2:
        var player_0: Dictionary = players[0]
        assert_true(bool(player_0.get("in_inspection", false)), "snapshot includes inspection=true for player 0")
    var sent_to_inspection: Array[Dictionary] = _filter_events(client_a, "rpc_player_sent_to_inspection")
    assert_eq(sent_to_inspection.size(), 1, "inspection mutation event emitted")
    if sent_to_inspection.size() == 1:
        assert_eq(str(sent_to_inspection[0].get("reason", "")), "bear_legal_inspection", "reason is inspection card id")


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results


func _find_seed_for_doubles(expect_doubles: bool) -> int:
    var probe_rng: RandomNumberGenerator = RandomNumberGenerator.new()
    for seed_value in range(1, 100000):
        probe_rng.seed = seed_value
        var die_1: int = probe_rng.randi_range(1, 6)
        var die_2: int = probe_rng.randi_range(1, 6)
        var is_doubles: bool = die_1 == die_2
        if is_doubles == expect_doubles:
            return seed_value
    assert(false)
    return 1
