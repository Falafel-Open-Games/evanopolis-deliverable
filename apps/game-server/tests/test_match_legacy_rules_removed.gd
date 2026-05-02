extends GutTest

const Config = preload("res://scripts/config.gd")
const GameMatch = preload("res://scripts/match.gd")
const MatchTestClient = preload("res://tests/match_test_client.gd")


func test_board_has_only_property_tiles() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])

    var tiles: Array = game_match.board_state.get("tiles", [])
    assert_eq(tiles.size(), 18, "new rules board always has 18 tiles")
    for index in range(tiles.size()):
        var tile: Dictionary = tiles[index]
        assert_eq(str(tile.get("tile_type", "")), "property", "tile %d should be a property tile" % index)
        assert_eq(int(tile.get("index", -1)), index, "tile %d index matches position" % index)
        assert_ne(str(tile.get("city", "")), "", "tile %d has a canonical city name" % index)


func test_tile_four_is_patagonia_property_not_legacy_special_tile() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])

    var tile: Dictionary = game_match._tile_from_index(4)
    assert_eq(str(tile.get("tile_type", "")), "property", "tile 4 is no longer an incident tile")
    assert_eq(str(tile.get("city", "")), "Patagonia", "tile 4 belongs to Patagonia")
    assert_eq(str(game_match._action_required_for_tile(str(tile.get("tile_type", "")), -1, 0)), "buy_or_end_turn", "unowned property still offers buy or end turn")


func test_legacy_inspection_and_incident_rpc_entry_points_are_inert() -> void:
    var config: Config = Config.from_values("demo_002", 2, 18)
    var game_match: GameMatch = GameMatch.new(config, [])
    var client_a: MatchTestClient = MatchTestClient.new()
    var client_b: MatchTestClient = MatchTestClient.new()
    assert_eq(str(game_match.assign_client("alice", client_a).get("reason", "")), "", "first client should register")
    assert_eq(str(game_match.assign_client("bob", client_b).get("reason", "")), "", "second client should register")

    game_match.rpc_roll_dice("demo_002", "alice")
    var tile_landed: Array[Dictionary] = _filter_events(client_a, "rpc_tile_landed")
    assert_eq(tile_landed.size(), 1, "roll still resolves to a landing tile")
    if tile_landed.size() == 1:
        assert_eq(str(tile_landed[0].get("action_required", "")), "buy_or_end_turn", "no legacy special action is attached to the landing tile")


func test_removed_server_request_rpcs_are_not_exposed() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    assert_false(server.has_method("rpc_buy_miner_batch"), "miner purchase rpc removed from server surface")


func _filter_events(client: MatchTestClient, method: String) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for event in client.events:
        if str(event.get("method", "")) == method:
            results.append(event)
    return results
