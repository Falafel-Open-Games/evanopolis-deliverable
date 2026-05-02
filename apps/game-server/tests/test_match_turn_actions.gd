extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_roll_emits_landing_context_for_property_tile() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(landed.size(), 1, "tile landed should be emitted after roll")
    var event: Dictionary = landed[0]
    assert_eq(int(event.get("tile_index", -1)), 6, "first roll for demo_002 lands on tile 6")
    assert_eq(str(event.get("tile_type", "")), "property", "landing tile type")
    assert_eq(str(event.get("city", "")), "assuncion", "landing city name")
    assert_eq(int(event.get("owner_index", -99)), -1, "unowned property")
    assert_eq(float(event.get("toll_due", -1.0)), 0.0, "no toll on unowned property")
    assert_true(is_equal_approx(float(event.get("buy_price", -1.0)), 4.0), "buy price provided for unowned property")
    assert_eq(str(event.get("action_required", "")), "buy_or_end_turn", "expected action for unowned property")


func test_landing_context_for_owned_property_by_other_player() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(landed.size(), 1, "tile landed should be emitted")
    var event: Dictionary = landed[0]
    assert_eq(int(event.get("tile_index", -1)), 6, "expected property tile index")
    assert_eq(str(event.get("tile_type", "")), "property", "property tile type")
    assert_eq(str(event.get("city", "")), "assuncion", "property city")
    assert_eq(int(event.get("owner_index", -99)), 1, "owner is other player")
    assert_true(is_equal_approx(float(event.get("toll_due", -1.0)), 0.6), "assuncion toll with 2 miner batches at cycle 1")
    assert_eq(float(event.get("buy_price", -1.0)), 0.0, "owned property has no buy price")
    assert_eq(str(event.get("action_required", "")), "pay_toll", "owned by other requires pay_toll")


func test_landing_context_for_owned_property_by_self() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 0
    tile["miner_batches"] = 4
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(landed.size(), 1, "tile landed should be emitted")
    var event: Dictionary = landed[0]
    assert_eq(int(event.get("owner_index", -99)), 0, "owner is landing player")
    assert_eq(float(event.get("toll_due", -1.0)), 0.0, "self-owned property has no toll")
    assert_eq(float(event.get("buy_price", -1.0)), 0.0, "self-owned property has no buy price")
    assert_eq(str(event.get("action_required", "")), "end_turn", "self-owned property ends turn")


func test_owned_property_landing_without_miners_emits_no_btc_reward() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 0
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var mining_events: Array[Dictionary] = _filter_events(client_a, "rpc_mining_reward")
    assert_eq(mining_events.size(), 1, "mining reward event should still be emitted for owned tile")
    if mining_events.size() == 1:
        assert_eq(int(mining_events[0].get("owner_index", -1)), 1, "owner is included in mining reward event")
        assert_eq(int(mining_events[0].get("miner_batches", -1)), 0, "no miner batches reflected in event")
        assert_true(is_equal_approx(float(mining_events[0].get("btc_reward", -1.0)), 0.0), "zero payout when no miners")
        assert_eq(str(mining_events[0].get("reason", "")), "no_miners", "reason explains zero payout")
    var balance_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    for event in balance_events:
        assert_ne(str(event.get("reason", "")), "property_landing_mining_reward", "no mining reward reason when miner count is zero")


func test_owned_property_landing_by_other_player_emits_owner_btc_reward() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var mining_events: Array[Dictionary] = _filter_events(client_a, "rpc_mining_reward")
    assert_eq(mining_events.size(), 1, "mining reward event emitted")
    if mining_events.size() == 1:
        assert_eq(int(mining_events[0].get("owner_index", -1)), 1, "owner in mining event")
        assert_eq(int(mining_events[0].get("miner_batches", -1)), 2, "miner batches in mining event")
        assert_true(is_equal_approx(float(mining_events[0].get("btc_reward", -1.0)), 4.0), "mining event payout")
        assert_eq(str(mining_events[0].get("reason", "")), "rewarded", "mining event reward reason")
    var balance_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    assert_true(balance_events.size() >= 1, "mining payout should emit balance change")
    if balance_events.size() >= 1:
        var latest_balance: Dictionary = balance_events[balance_events.size() - 1]
        assert_eq(int(latest_balance.get("player_index", -1)), 1, "owner receives mining payout")
        assert_true(is_equal_approx(float(latest_balance.get("fiat_delta", -1.0)), 0.0), "mining payout has no fiat delta")
        assert_true(is_equal_approx(float(latest_balance.get("btc_delta", -1.0)), 4.0), "2 miner batches pay 4.0 BTC")
        assert_eq(str(latest_balance.get("reason", "")), "property_landing_mining_reward", "expected mining payout reason")


func test_owned_property_landing_emits_mining_reward_to_all_clients() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var mining_events_a: Array[Dictionary] = _filter_events(client_a, "rpc_mining_reward")
    var mining_events_b: Array[Dictionary] = _filter_events(client_b, "rpc_mining_reward")
    assert_eq(mining_events_a.size(), 1, "acting client receives mining reward event")
    assert_eq(mining_events_b.size(), 1, "other client receives mining reward event")
    if mining_events_a.size() == 1 and mining_events_b.size() == 1:
        assert_eq(int(mining_events_a[0].get("owner_index", -1)), int(mining_events_b[0].get("owner_index", -2)), "owner is consistent")
        assert_eq(int(mining_events_a[0].get("tile_index", -1)), int(mining_events_b[0].get("tile_index", -2)), "tile is consistent")
        assert_eq(int(mining_events_a[0].get("miner_batches", -1)), int(mining_events_b[0].get("miner_batches", -2)), "miner batches are consistent")
        assert_true(
            is_equal_approx(float(mining_events_a[0].get("btc_reward", -1.0)), float(mining_events_b[0].get("btc_reward", -2.0))),
            "btc reward is consistent",
        )
        assert_eq(str(mining_events_a[0].get("reason", "")), str(mining_events_b[0].get("reason", "_mismatch")), "reason is consistent")


func test_reaching_btc_goal_ends_match_immediately_on_mining_reward() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 1
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles
    game_match.state.players[1].bitcoin_balance = 19.0

    game_match._server_move_pawn(6)

    assert_true(game_match.has_finished, "match should be finished once goal is reached")
    assert_eq(game_match.winner_index, 1, "owner reaching BTC goal wins immediately")
    assert_eq(game_match.end_reason, "btc_goal_reached", "end reason indicates goal-based finish")
    assert_true(game_match.pending_action.is_empty(), "pending action should be cleared when match ends")
    assert_eq(game_match.state.current_player_index, 0, "turn should not advance after terminal event")

    var ended_events: Array[Dictionary] = _filter_events(client_a, "rpc_game_ended")
    assert_eq(ended_events.size(), 1, "game ended event emitted once")
    if ended_events.size() == 1:
        assert_eq(int(ended_events[0].get("winner_index", -1)), 1, "winner index in event")
        assert_eq(str(ended_events[0].get("reason", "")), "btc_goal_reached", "end reason in event")
        assert_true(is_equal_approx(float(ended_events[0].get("btc_goal", -1.0)), 21.0), "btc goal in event")
        assert_true(is_equal_approx(float(ended_events[0].get("winner_btc", -1.0)), 21.0), "winner btc in event")


func test_owned_property_landing_by_owner_emits_owner_btc_reward_without_toll() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 0
    tile["miner_batches"] = 3
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var mining_events: Array[Dictionary] = _filter_events(client_a, "rpc_mining_reward")
    assert_eq(mining_events.size(), 1, "mining reward event emitted")
    if mining_events.size() == 1:
        assert_eq(int(mining_events[0].get("owner_index", -1)), 0, "owner in mining event")
        assert_eq(int(mining_events[0].get("miner_batches", -1)), 3, "miner batches in mining event")
        assert_true(is_equal_approx(float(mining_events[0].get("btc_reward", -1.0)), 6.0), "mining event payout")
        assert_eq(str(mining_events[0].get("reason", "")), "rewarded", "mining event reward reason")
    var balance_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    assert_true(balance_events.size() >= 1, "owner landing should emit mining payout")
    if balance_events.size() >= 1:
        var latest_balance: Dictionary = balance_events[balance_events.size() - 1]
        assert_eq(int(latest_balance.get("player_index", -1)), 0, "owner receives payout on own landing")
        assert_true(is_equal_approx(float(latest_balance.get("btc_delta", -1.0)), 6.0), "3 miner batches pay 6.0 BTC")
        assert_eq(str(latest_balance.get("reason", "")), "property_landing_mining_reward", "expected mining payout reason")
    var toll_events: Array[Dictionary] = _filter_events(client_a, "rpc_toll_paid")
    assert_eq(toll_events.size(), 0, "owner landing does not emit toll payment event")


func test_owned_property_landing_does_not_emit_btc_reward_when_owner_is_in_inspection() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles
    game_match.state.players[1].in_inspection = true

    game_match._server_move_pawn(6)
    var mining_events: Array[Dictionary] = _filter_events(client_a, "rpc_mining_reward")
    assert_eq(mining_events.size(), 1, "mining reward event emitted even when blocked")
    if mining_events.size() == 1:
        assert_true(is_equal_approx(float(mining_events[0].get("btc_reward", -1.0)), 0.0), "inspection blocks payout amount")
        assert_eq(str(mining_events[0].get("reason", "")), "owner_in_inspection", "reason explains blocked payout")
    var balance_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    for event in balance_events:
        assert_ne(str(event.get("reason", "")), "property_landing_mining_reward", "inspection blocks mining payout")


func test_buy_property_resolves_pending_action_and_advances_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var buy_reason: String = game_match.rpc_buy_property("demo_002", "alice", 6)
    assert_eq(buy_reason, "", "buy property should succeed")
    assert_true(game_match.pending_action.is_empty(), "pending action cleared after successful buy")

    var tile: Dictionary = game_match._tile_from_index(6)
    assert_eq(int(tile.get("owner_index", -1)), 0, "tile ownership transferred to buyer")
    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 116.0), "buyer fiat balance reduced by property price")

    var acquired: Array[Dictionary] = _filter_events(client_a, "rpc_property_acquired")
    assert_eq(acquired.size(), 1, "property acquired event emitted once")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "next turn starts after buy resolution")
    assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advanced to next player")
    assert_true(int(acquired[0].get("seq", -1)) < int(turns[1].get("seq", -1)), "property acquired emitted before next turn started")


func test_end_turn_resolves_pending_action_without_purchase() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var end_reason: String = game_match.rpc_end_turn("demo_002", "alice")
    assert_eq(end_reason, "", "end turn should succeed")
    assert_true(game_match.pending_action.is_empty(), "pending action cleared after end turn")

    var tile: Dictionary = game_match._tile_from_index(6)
    assert_eq(int(tile.get("owner_index", -1)), -1, "tile remains unowned when buy is skipped")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "next turn starts after end turn resolution")
    assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advanced to next player")


func test_pay_toll_resolves_pending_action_and_advances_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    var pay_reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(pay_reason, "", "pay toll should succeed")
    assert_true(game_match.pending_action.is_empty(), "pending action cleared after pay toll")
    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 119.4), "payer fiat reduced by toll")
    assert_true(is_equal_approx(game_match.state.players[1].fiat_balance, 120.6), "owner fiat increased by toll")

    var toll_paid: Array[Dictionary] = _filter_events(client_a, "rpc_toll_paid")
    assert_eq(toll_paid.size(), 1, "toll paid event emitted once")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "next turn starts after pay toll resolution")
    assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advanced to next player")
    assert_true(int(toll_paid[0].get("seq", -1)) < int(turns[1].get("seq", -1)), "toll paid emitted before next turn started")


func test_buy_property_rejected_without_pending_action() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 6)
    assert_eq(reason, "no_pending_action", "buy requires pending action")


func test_pay_toll_rejected_without_pending_action() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "no_pending_action", "pay toll requires pending action")


func test_pay_toll_insufficient_fiat_sends_player_to_inspection_and_advances_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.state.players[0].fiat_balance = 0.1
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "", "pay toll resolves with inspection when payer cannot afford toll")
    assert_true(game_match.state.players[0].in_inspection, "payer is sent to inspection")
    assert_eq(game_match.state.current_player_index, 1, "turn advances to next player")

    var toll_events: Array[Dictionary] = _filter_events(client_a, "rpc_toll_paid")
    assert_eq(toll_events.size(), 0, "no toll payment event emitted when player cannot pay")
    var inspection_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_sent_to_inspection")
    assert_eq(inspection_events.size(), 1, "inspection event emitted when player cannot pay toll")
    if inspection_events.size() == 1:
        assert_eq(str(inspection_events[0].get("reason", "")), "insufficient_fiat_toll", "inspection reason is insufficient toll fiat")


func test_pay_toll_insufficient_fiat_keeps_prior_mining_reward_to_owner() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.state.players[0].fiat_balance = 0.1
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "", "pay toll resolves to inspection when payer cannot afford toll")
    assert_true(game_match.state.players[0].in_inspection, "payer is sent to inspection")
    assert_eq(game_match.state.current_player_index, 1, "turn advances to next player")
    assert_true(is_equal_approx(game_match.state.players[1].bitcoin_balance, 4.0), "owner keeps mining reward from landing")

    var mining_events: Array[Dictionary] = _filter_events(client_a, "rpc_mining_reward")
    assert_eq(mining_events.size(), 1, "mining reward event emitted from landing context")
    if mining_events.size() == 1:
        assert_eq(str(mining_events[0].get("reason", "")), "rewarded", "mining reward reason indicates payout")
        assert_true(is_equal_approx(float(mining_events[0].get("btc_reward", -1.0)), 4.0), "mining reward amount is preserved")
    var balance_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    var found_owner_mining_delta: bool = false
    for event in balance_events:
        if int(event.get("player_index", -1)) == 1 and str(event.get("reason", "")) == "property_landing_mining_reward":
            found_owner_mining_delta = true
            assert_true(is_equal_approx(float(event.get("btc_delta", -1.0)), 4.0), "owner mining balance delta emitted")
    assert_true(found_owner_mining_delta, "owner mining balance delta should be emitted before toll resolution")
    var inspection_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_sent_to_inspection")
    assert_eq(inspection_events.size(), 1, "inspection event still emitted for insufficient toll payer")


func test_actions_are_rejected_after_match_finished() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 1
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles
    game_match.state.players[1].bitcoin_balance = 19.0
    game_match._server_move_pawn(6)
    assert_true(game_match.has_finished, "match should already be finished")

    assert_eq(game_match.rpc_end_turn("demo_002", "alice"), "match_finished", "end_turn blocked after game end")
    assert_eq(game_match.rpc_buy_property("demo_002", "alice", 6), "match_finished", "buy blocked after game end")
    assert_eq(game_match.rpc_buy_miner_batch("demo_002", "alice", 6), "match_finished", "miner buy blocked after game end")
    assert_eq(game_match.rpc_pay_toll("demo_002", "alice"), "match_finished", "pay toll blocked after game end")
    assert_eq(game_match.rpc_pay_inspection_fee("demo_002", "alice"), "match_finished", "inspection fee blocked after game end")
    assert_eq(game_match.rpc_roll_inspection_exit("demo_002", "alice"), "match_finished", "inspection roll blocked after game end")
    assert_eq(game_match.rpc_use_inspection_voucher("demo_002", "alice"), "match_finished", "inspection voucher blocked after game end")

    game_match.rpc_roll_dice("demo_002", "alice")
    var rejected: Array[Dictionary] = _filter_events(client_a, "rpc_action_rejected")
    assert_true(rejected.size() >= 1, "roll should emit action rejection after game end")
    if rejected.size() >= 1:
        var latest_rejection: Dictionary = rejected[rejected.size() - 1]
        assert_eq(str(latest_rejection.get("reason", "")), "match_finished", "roll rejection reason after game end")


func test_pay_toll_rejected_for_non_current_player() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_pay_toll("demo_002", "bob")
    assert_eq(reason, "not_current_player", "only current player can pay toll")


func test_pay_toll_rejected_when_pending_action_type_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "action_not_allowed", "pay toll rejected when pending action is buy_or_end_turn")


func test_pay_toll_rejected_with_invalid_owner_index() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.pending_action["owner_index"] = 99
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "invalid_owner", "pay toll rejects invalid owner index")


func test_pay_toll_rejected_when_owner_is_payer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.pending_action["owner_index"] = 0
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "invalid_owner", "pay toll rejects self as owner")


func test_pay_toll_rejected_with_invalid_toll_amount() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.pending_action["amount"] = 0.0
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "invalid_toll_amount", "pay toll rejects non-positive toll amount")


func test_end_turn_rejected_for_non_current_player() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_end_turn("demo_002", "bob")
    assert_eq(reason, "not_current_player", "only current player can resolve pending action")


func test_buy_property_rejected_on_tile_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 5)
    assert_eq(reason, "tile_mismatch", "buy must match pending tile")


func test_buy_property_rejected_when_property_already_owned() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var tile: Dictionary = game_match._tile_from_index(6)
    tile["owner_index"] = 1
    var tiles: Array = game_match.board_state.get("tiles", [])
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 6)
    assert_eq(reason, "property_already_owned", "buy rejects if property is already owned")


func test_buy_property_rejected_for_insufficient_fiat() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.state.players[0].fiat_balance = 1.0
    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 6)
    assert_eq(reason, "insufficient_fiat", "buy rejects when player cannot afford property")


func test_turn_number_increments_after_last_player_ends_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    assert_eq(game_match.rpc_end_turn("demo_002", "alice"), "", "alice ends turn")
    game_match.rpc_roll_dice("demo_002", "bob")
    assert_eq(game_match.rpc_end_turn("demo_002", "bob"), "", "bob ends turn")

    assert_eq(game_match.state.current_player_index, 0, "turn wraps to first player")
    assert_eq(game_match.state.turn_number, 2, "turn number increments after last player resolves turn")


func test_buy_miner_batch_updates_balance_and_tile_state() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    # Alice owns tile 6.
    game_match.rpc_roll_dice("demo_002", "alice")
    assert_eq(game_match.rpc_buy_property("demo_002", "alice", 6), "", "buy succeeds")
    # Bob ends quickly.
    game_match.rpc_roll_dice("demo_002", "bob")
    assert_eq(game_match.rpc_end_turn("demo_002", "bob"), "", "bob ends turn")

    # Alice buys one miner batch on owned tile.
    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", 6)
    assert_eq(reason, "", "buy miner batch should succeed")

    var tile: Dictionary = game_match._tile_from_index(6)
    assert_eq(int(tile.get("miner_batches", -1)), 1, "tile miner batches incremented")
    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 108.0), "fiat reduced by miner batch price")

    var balance_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    assert_true(balance_events.size() >= 1, "balance change emitted")
    if balance_events.size() >= 1:
        var latest_balance: Dictionary = balance_events[balance_events.size() - 1]
        assert_true(is_equal_approx(float(latest_balance.get("fiat_delta", 0.0)), -8.0), "miner purchase delta")
        assert_eq(str(latest_balance.get("reason", "")), "miner_batch_purchased", "miner purchase reason")
    var miner_events: Array[Dictionary] = _filter_events(client_a, "rpc_miner_batches_added")
    assert_eq(miner_events.size(), 1, "miner batch added event emitted")
    if miner_events.size() == 1:
        assert_eq(int(miner_events[0].get("tile_index", -1)), 6, "miner event tile")
        assert_eq(int(miner_events[0].get("count", -1)), 1, "miner event count")


func test_buy_miner_batch_rejected_for_non_owner_tile() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", 6)
    assert_eq(reason, "not_property_owner", "cannot place miner on unowned property")


func test_buy_miner_batch_rejected_for_insufficient_fiat() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    # Alice owns tile 6.
    game_match.rpc_roll_dice("demo_002", "alice")
    assert_eq(game_match.rpc_buy_property("demo_002", "alice", 6), "", "buy succeeds")
    # Bob ends quickly.
    game_match.rpc_roll_dice("demo_002", "bob")
    assert_eq(game_match.rpc_end_turn("demo_002", "bob"), "", "bob ends turn")

    game_match.state.players[0].fiat_balance = 7.0
    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", 6)
    assert_eq(reason, "insufficient_fiat", "miner purchase requires sufficient fiat")


func test_buy_miner_batch_rejected_for_max_miner_batches_reached() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    assert_eq(game_match.rpc_buy_property("demo_002", "alice", 6), "", "buy succeeds")
    game_match.rpc_roll_dice("demo_002", "bob")
    assert_eq(game_match.rpc_end_turn("demo_002", "bob"), "", "bob ends turn")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["miner_batches"] = 4
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", 6)
    assert_eq(reason, "max_miner_batches_reached", "cannot exceed miner capacity")


func test_buy_miner_batch_rejected_for_non_property_tile() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", 0)
    assert_eq(reason, "tile_not_mineable", "non-property tiles are not mineable")


func test_buy_miner_batch_rejected_while_pending_action_exists() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", 6)
    assert_eq(reason, "pending_action_required", "miner purchase blocked while pending action exists")


func test_buy_miner_batch_rejected_while_in_inspection() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].in_inspection = true
    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", 6)
    assert_eq(reason, "inspection_resolution_required", "miner purchase blocked while in inspection")


func test_buy_miner_batch_rejected_for_non_current_player() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "bob", 6)
    assert_eq(reason, "not_current_player", "only current player can buy miners")


func test_buy_miner_batch_rejected_for_invalid_tile_index() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_buy_miner_batch("demo_002", "alice", -1)
    assert_eq(reason, "invalid_tile_index", "tile index must be in board range")


func test_buy_miner_batch_emits_balance_change_before_miner_added() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    assert_eq(game_match.rpc_buy_property("demo_002", "alice", 6), "", "buy succeeds")
    game_match.rpc_roll_dice("demo_002", "bob")
    assert_eq(game_match.rpc_end_turn("demo_002", "bob"), "", "bob ends turn")

    assert_eq(game_match.rpc_buy_miner_batch("demo_002", "alice", 6), "", "miner purchase succeeds")
    var balance_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    var miner_events: Array[Dictionary] = _filter_events(client_a, "rpc_miner_batches_added")
    assert_true(balance_events.size() >= 1, "balance event emitted")
    assert_eq(miner_events.size(), 1, "miner event emitted")
    if balance_events.size() >= 1 and miner_events.size() == 1:
        var latest_balance: Dictionary = balance_events[balance_events.size() - 1]
        assert_true(
            int(latest_balance.get("seq", -1)) < int(miner_events[0].get("seq", -1)),
            "balance change should be emitted before miner added event",
        )


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results
