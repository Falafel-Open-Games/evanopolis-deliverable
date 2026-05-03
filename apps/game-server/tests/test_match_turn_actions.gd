extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_visual_ring_starting_tile_is_derived_from_color_side_center() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])

    var player: PlayerState = game_match.state.players[0]
    player.color_id = 1
    assert_eq(game_match._starting_tile_for_color(1), 15, "green starts at tile 15")
    assert_eq(game_match._starting_tile_for_color(4), 6, "purple starts at tile 6")
    assert_eq(game_match._starting_tile_for_color(0), 12, "ice starts at tile 12")


func test_legacy_board_size_inputs_normalize_to_18_tiles() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])

    var tiles: Array = game_match.board_state.get("tiles", [])
    assert_eq(tiles.size(), 18, "new rules board always has 18 tiles")
    for index in range(tiles.size()):
        var tile: Dictionary = tiles[index]
        assert_true(["A", "B", "C"].has(str(tile.get("tile_type", ""))), "tile %d should be an economy property tile" % index)
        assert_eq(int(tile.get("index", -1)), index, "tile %d index matches position" % index)
        assert_ne(str(tile.get("city", "")), "", "tile %d has a canonical city name" % index)


func test_tile_four_is_patagonia_property_not_legacy_special_tile() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])

    var tile: Dictionary = game_match._tile_from_index(4)
    assert_eq(str(tile.get("tile_type", "")), "B", "tile 4 is Patagonia's B property")
    assert_eq(str(tile.get("city", "")), "Patagonia", "tile 4 belongs to Patagonia")
    assert_eq(str(game_match._action_required_for_tile(str(tile.get("tile_type", "")), -1, 0)), "buy_or_end_turn", "unowned property still offers buy or end turn")


func test_roll_emits_landing_context_for_property_tile() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")

    var tile_landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(tile_landed.size(), 1, "roll should emit a landing tile")
    if tile_landed.size() == 1:
        assert_eq(str(tile_landed[0].get("action_required", "")), "buy_or_end_turn", "unowned property offers buy or end turn")
        assert_eq(float(tile_landed[0].get("buy_price", 0.0)), 34.0, "landing context includes V0 buy price")
        assert_eq(int(tile_landed[0].get("energy_production", 0)), 8, "landing context includes V0 energy output")
        assert_eq(float(tile_landed[0].get("sell_100_fiat", 0.0)), 4.0, "landing context includes V0 sell output")
        assert_eq(float(tile_landed[0].get("mine_100_btc", 0.0)), 0.75, "landing context includes V0 mining output")


func test_landing_context_for_owned_property_by_other_player() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var tile_landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(tile_landed.size(), 1, "landing tile emitted once")
    if tile_landed.size() == 1:
        var event: Dictionary = tile_landed[0]
        assert_eq(int(event.get("owner_index", -99)), 1, "owner is the other player")
        assert_true(float(event.get("toll_due", -1.0)) > 0.0, "owned property has toll due")
        assert_eq(str(event.get("action_required", "")), "pay_toll", "other-owned property requires toll payment")


func test_landing_context_for_owned_property_by_self() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 0
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match._server_move_pawn(6)
    var tile_landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(tile_landed.size(), 1, "tile landed should be emitted")
    var event: Dictionary = tile_landed[0]
    assert_eq(int(event.get("owner_index", -99)), 0, "owner is landing player")
    assert_eq(float(event.get("toll_due", -1.0)), 0.0, "self-owned property has no toll")
    assert_eq(float(event.get("buy_price", -1.0)), 0.0, "self-owned property has no buy price")
    assert_eq(str(event.get("action_required", "")), "end_turn", "self-owned property ends turn")


func test_buy_property_resolves_pending_action_and_advances_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var buy_reason: String = game_match.rpc_buy_property("demo_002", "alice", 0)
    assert_eq(buy_reason, "", "buy property should succeed")
    assert_true(game_match.pending_action.is_empty(), "pending action cleared after successful buy")

    var tile: Dictionary = game_match._tile_from_index(0)
    assert_eq(int(tile.get("owner_index", -1)), 0, "tile ownership transferred to buyer")
    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 96.0), "buyer fiat balance reduced by property price")

    var acquired: Array[Dictionary] = _filter_events(client_a, "rpc_property_acquired")
    assert_eq(acquired.size(), 1, "property acquired event emitted once")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "next turn starts after buy resolution")
    assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advanced to next player")
    assert_true(int(acquired[0].get("seq", -1)) < int(turns[1].get("seq", -1)), "property acquired emitted before next turn started")


func test_end_turn_resolves_pending_action_without_purchase() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var end_reason: String = game_match.rpc_end_turn("demo_002", "alice")
    assert_eq(end_reason, "", "end turn should succeed")
    assert_true(game_match.pending_action.is_empty(), "pending action cleared after end turn")

    var tile: Dictionary = game_match._tile_from_index(0)
    assert_eq(int(tile.get("owner_index", -1)), -1, "tile remains unowned when buy is skipped")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "next turn starts after end turn resolution")
    assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advanced to next player")


func test_pay_toll_resolves_pending_action_and_advances_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    var pay_reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(pay_reason, "", "pay toll should succeed")
    assert_true(game_match.pending_action.is_empty(), "pending action cleared after pay toll")
    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 126.6), "payer fiat reduced by toll")
    assert_true(is_equal_approx(game_match.state.players[1].fiat_balance, 133.4), "owner fiat increased by toll")

    var toll_paid: Array[Dictionary] = _filter_events(client_a, "rpc_toll_paid")
    assert_eq(toll_paid.size(), 1, "toll paid event emitted once")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "next turn starts after pay toll resolution")
    assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advanced to next player")
    assert_true(int(toll_paid[0].get("seq", -1)) < int(turns[1].get("seq", -1)), "toll paid emitted before next turn started")


func test_buy_property_rejected_without_pending_action() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 0)
    assert_eq(reason, "no_pending_action", "buy requires pending action")


func test_pay_toll_rejected_without_pending_action() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "no_pending_action", "pay toll requires pending action")


func test_pay_toll_insufficient_fiat_keeps_pending_action() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.state.players[0].fiat_balance = 0.1
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "insufficient_fiat", "pay toll should fail when payer cannot afford toll")
    assert_eq(game_match.state.current_player_index, 0, "turn does not advance until toll is resolved")
    assert_false(game_match.pending_action.is_empty(), "pending toll action remains active")

    var toll_events: Array[Dictionary] = _filter_events(client_a, "rpc_toll_paid")
    assert_eq(toll_events.size(), 0, "no toll payment event emitted when player cannot pay")


func test_actions_are_rejected_after_match_finished() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles
    game_match.has_finished = true
    game_match.winner_index = 1
    game_match.end_reason = "manual_test"

    assert_eq(game_match.rpc_end_turn("demo_002", "alice"), "match_finished", "end_turn blocked after game end")
    assert_eq(game_match.rpc_buy_property("demo_002", "alice", 0), "match_finished", "buy blocked after game end")
    assert_eq(game_match.rpc_pay_toll("demo_002", "alice"), "match_finished", "pay toll blocked after game end")

    game_match.rpc_roll_dice("demo_002", "alice")
    var rejected: Array[Dictionary] = _filter_events(client_a, "rpc_action_rejected")
    assert_true(rejected.size() >= 1, "roll should emit action rejection after game end")
    if rejected.size() >= 1:
        var latest_rejection: Dictionary = rejected[rejected.size() - 1]
        assert_eq(str(latest_rejection.get("reason", "")), "match_finished", "roll rejection reason after game end")


func test_pay_toll_rejected_for_non_current_player() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_pay_toll("demo_002", "bob")
    assert_eq(reason, "not_current_player", "only current player can pay toll")


func test_pay_toll_rejected_when_pending_action_type_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "action_not_allowed", "pay toll rejected when pending action is buy_or_end_turn")


func test_pay_toll_rejected_with_invalid_owner_index() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.pending_action["owner_index"] = 99
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "invalid_owner", "pay toll rejects invalid owner index")


func test_pay_toll_rejected_when_owner_is_payer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.pending_action["owner_index"] = 0
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "invalid_owner", "pay toll rejects self as owner")


func test_pay_toll_rejected_with_invalid_toll_amount() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[0]
    tile["owner_index"] = 1
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.pending_action["amount"] = 0.0
    var reason: String = game_match.rpc_pay_toll("demo_002", "alice")
    assert_eq(reason, "invalid_toll_amount", "pay toll rejects non-positive toll amount")


func test_end_turn_rejected_for_non_current_player() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
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
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 5)
    assert_eq(reason, "tile_mismatch", "buy must match pending tile")


func test_buy_property_rejected_when_property_already_owned() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var tile: Dictionary = game_match._tile_from_index(0)
    tile["owner_index"] = 1
    var tiles: Array = game_match.board_state.get("tiles", [])
    tiles[0] = tile
    game_match.board_state["tiles"] = tiles

    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 0)
    assert_eq(reason, "property_already_owned", "buy rejects if property is already owned")


func test_buy_property_rejected_for_insufficient_fiat() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    game_match.state.players[0].fiat_balance = 1.0
    var reason: String = game_match.rpc_buy_property("demo_002", "alice", 0)
    assert_eq(reason, "insufficient_fiat", "buy rejects when player cannot afford property")


func test_turn_number_increments_after_last_player_ends_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
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


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results
