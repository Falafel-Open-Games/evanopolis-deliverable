extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_landing_context_for_non_property_tile() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()

    var result_a: Dictionary = game_match.assign_client("alice", client_a)
    assert_eq(str(result_a.get("reason", "")), "", "first client should register")
    var result_b: Dictionary = game_match.assign_client("bob", client_b)
    assert_eq(str(result_b.get("reason", "")), "", "second client should register")

    game_match._server_move_pawn(4)
    var landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(landed.size(), 1, "tile landed should be emitted")
    var event: Dictionary = landed[0]
    assert_eq(int(event.get("tile_index", -1)), 4, "expected incident tile index")
    assert_eq(str(event.get("tile_type", "")), "incident", "incident tile type")
    assert_eq(str(event.get("city", "")), "", "non-property has no city")
    assert_eq(int(event.get("owner_index", -99)), -1, "non-property has no owner")
    assert_eq(float(event.get("toll_due", -1.0)), 0.0, "non-property has no toll")
    assert_eq(float(event.get("buy_price", -1.0)), 0.0, "non-property has no buy price")
    assert_eq(str(event.get("action_required", "")), "resolve_incident", "incident requires incident resolution")


func test_incident_resolution_emits_events_flips_tile_and_advances_turn() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match._server_move_pawn(4)

    var incident_drawn: Array[Dictionary] = _filter_events(client_a, "rpc_incident_drawn")
    assert_eq(incident_drawn.size(), 1, "incident draw event emitted once")
    var incident_flip: Array[Dictionary] = _filter_events(client_a, "rpc_incident_type_changed")
    assert_eq(incident_flip.size(), 1, "incident tile flip event emitted once")
    if incident_flip.size() == 1:
        assert_eq(str(incident_flip[0].get("incident_kind", "")), "bull", "incident tile flips from bear to bull")

    var mutation_count: int = 0
    mutation_count += _filter_events(client_a, "rpc_player_balance_changed").size()
    mutation_count += _filter_events(client_a, "rpc_player_sent_to_inspection").size()
    mutation_count += _filter_events(client_a, "rpc_inspection_voucher_granted").size()
    assert_true(mutation_count >= 1, "incident resolution emits at least one mutation event")

    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")
    assert_eq(turns.size(), 2, "next turn starts after incident resolution")
    assert_eq(int(turns[1].get("player_index", -1)), 1, "turn advanced to next player")
    assert_true(game_match.pending_action.is_empty(), "pending action cleared after incident resolution")

    if incident_flip.size() == 1 and turns.size() == 2:
        var flip_seq: int = int(incident_flip[0].get("seq", -1))
        var next_turn_seq: int = int(turns[1].get("seq", -1))
        assert_true(flip_seq < next_turn_seq, "incident flip emitted before next turn started")


func test_incident_event_order_is_strict() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match._server_move_pawn(4)

    var landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    var drawn: Array[Dictionary] = _filter_events(client_a, "rpc_incident_drawn")
    var balance_changed: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    var incident_flip: Array[Dictionary] = _filter_events(client_a, "rpc_incident_type_changed")
    var turns: Array[Dictionary] = _filter_events(client_a, "rpc_turn_started")

    assert_eq(landed.size(), 1, "one tile landed event")
    assert_eq(drawn.size(), 1, "one incident drawn event")
    assert_eq(balance_changed.size(), 1, "one balance mutation event for first bear card")
    assert_eq(incident_flip.size(), 1, "one incident flip event")
    assert_true(turns.size() >= 2, "at least two turn started events in stream")
    if landed.size() == 1 and drawn.size() == 1 and balance_changed.size() == 1 and incident_flip.size() == 1 and turns.size() >= 2:
        var tile_landed_seq: int = int(landed[0].get("seq", -1))
        var drawn_seq: int = int(drawn[0].get("seq", -1))
        var balance_seq: int = int(balance_changed[0].get("seq", -1))
        var flip_seq: int = int(incident_flip[0].get("seq", -1))
        var next_turn_seq: int = int(turns[turns.size() - 1].get("seq", -1))
        assert_true(tile_landed_seq < drawn_seq, "tile landed emitted before incident draw")
        assert_true(drawn_seq < balance_seq, "incident draw emitted before balance mutation")
        assert_true(balance_seq < flip_seq, "balance mutation emitted before tile flip")
        assert_true(flip_seq < next_turn_seq, "tile flip emitted before next turn started")


func test_incident_tile_flips_back_to_bear_on_second_landing() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match._server_move_pawn(4)
    game_match._server_move_pawn(4)

    var incident_flip: Array[Dictionary] = _filter_events(client_a, "rpc_incident_type_changed")
    assert_eq(incident_flip.size(), 2, "two incident flips emitted across two landings")
    if incident_flip.size() == 2:
        assert_eq(str(incident_flip[0].get("incident_kind", "")), "bull", "first landing flips bear->bull")
        assert_eq(str(incident_flip[1].get("incident_kind", "")), "bear", "second landing flips bull->bear")
    var tile: Dictionary = game_match._tile_from_index(4)
    assert_eq(str(tile.get("incident_kind", "")), "bear", "tile state returns to bear after second landing")


func test_incident_fiat_debit_insufficient_sends_player_to_inspection() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.state.players[0].fiat_balance = 0.1
    game_match._server_move_pawn(4)

    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 0.1), "incident debit is not applied when fiat is insufficient")
    assert_true(game_match.state.players[0].in_inspection, "player is sent to inspection on insufficient incident fiat")

    var balance_changed: Array[Dictionary] = _filter_events(client_a, "rpc_player_balance_changed")
    assert_eq(balance_changed.size(), 0, "no balance mutation event emitted when fiat is insufficient")
    var inspection_events: Array[Dictionary] = _filter_events(client_a, "rpc_player_sent_to_inspection")
    assert_eq(inspection_events.size(), 1, "inspection event emitted on insufficient incident fiat")
    if inspection_events.size() == 1:
        assert_eq(str(inspection_events[0].get("reason", "")), "insufficient_fiat_incident", "inspection reason is insufficient incident fiat")


func test_bear_deck_cycles_deterministically() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var game_match: GameMatch = GameMatch.new(config, [])

    var card_1: Dictionary = game_match._draw_incident_card("bear")
    var card_2: Dictionary = game_match._draw_incident_card("bear")
    var card_3: Dictionary = game_match._draw_incident_card("bear")
    var card_4: Dictionary = game_match._draw_incident_card("bear")

    assert_eq(str(card_1.get("card_id", "")), "bear_fine_eva_2", "first bear card")
    assert_eq(str(card_2.get("card_id", "")), "bear_fine_eva_3", "second bear card")
    assert_eq(str(card_3.get("card_id", "")), "bear_legal_inspection", "third bear card")
    assert_eq(str(card_4.get("card_id", "")), "bear_fine_eva_2", "bear deck wraps to first card")


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results
