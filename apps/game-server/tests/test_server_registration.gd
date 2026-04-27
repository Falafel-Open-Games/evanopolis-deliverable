extends GutTest

const Config = preload("res://scripts/config.gd")
const HeadlessServer = preload("res://scripts/server.gd")


func test_join_rejects_invalid_game_id() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    server.authorize_peer(1, "alice")
    var result: Dictionary = server.register_remote_client("missing_game", "alice", 1, null)
    assert_eq(str(result.get("reason", "")), "invalid_game_id", "invalid game id is rejected")


func test_rejects_duplicate_peer_registration() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(3, "bob")
    server.peer_slots[3] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }

    var result_b: Dictionary = server.register_remote_client("demo_002", "bob", 3, null)
    assert_eq(str(result_b.get("reason", "")), "peer_already_registered", "duplicate peer id rejected")


func test_reconnect_rebinds_peer_slot() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(11, "alice")
    server.authorize_peer(22, "alice")

    var first_join: Dictionary = server.register_remote_client("demo_002", "alice", 11, null)
    assert_eq(str(first_join.get("reason", "")), "", "first join succeeds")
    assert_true(server.peer_slots.has(11), "first peer slot exists")

    var reconnect_join: Dictionary = server.register_remote_client("demo_002", "alice", 22, null)
    assert_eq(str(reconnect_join.get("reason", "")), "", "reconnect succeeds")
    assert_eq(int(reconnect_join.get("replaced_peer_id", -1)), 11, "old peer id returned")
    assert_false(server.peer_slots.has(11), "old peer slot removed")
    assert_true(server.peer_slots.has(22), "new peer slot registered")


func test_sync_request_returns_snapshot_for_registered_peer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(11, "alice")
    server.authorize_peer(12, "bob")
    var first_join: Dictionary = server.register_remote_client("demo_002", "alice", 11, null)
    var second_join: Dictionary = server.register_remote_client("demo_002", "bob", 12, null)
    assert_eq(str(first_join.get("reason", "")), "", "first join succeeds")
    assert_eq(str(second_join.get("reason", "")), "", "second join succeeds")

    var roll_result: Dictionary = server.rpc_roll_dice("demo_002", "alice", 11)
    assert_eq(str(roll_result.get("reason", "")), "", "roll succeeds")

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds")
    assert_true(sync_result.has("snapshot"), "sync includes snapshot")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    var players: Array = snapshot.get("players", [])
    var board: Dictionary = snapshot.get("board_state", { })
    assert_eq(str(snapshot.get("game_id", "")), "demo_002", "snapshot includes game id")
    assert_eq(players.size(), 2, "snapshot includes player states")
    assert_false(snapshot.has("ready_players"), "snapshot no longer exposes top-level ready_players")
    assert_eq(int(board.get("size", 0)), 24, "snapshot includes board state")
    assert_true(int(sync_result.get("final_seq", -1)) > 0, "sync includes latest broadcast sequence")

    var first_player: Dictionary = players[0]
    var second_player: Dictionary = players[1]
    assert_eq(str(first_player.get("player_id", "")), "alice", "snapshot includes first player id")
    assert_true(bool(first_player.get("joined", false)), "snapshot marks first seat joined")
    assert_false(bool(first_player.get("ready", true)), "snapshot marks first seat not ready before ready signal")
    assert_eq(str(first_player.get("display_name", "")), "", "snapshot includes default first seat display name")
    assert_eq(int(first_player.get("icon_id", -1)), -1, "snapshot includes default first seat icon")
    assert_eq(int(first_player.get("color_id", -1)), 0, "snapshot includes default first seat color")
    assert_eq(str(second_player.get("player_id", "")), "bob", "snapshot includes second player id")
    assert_true(bool(second_player.get("joined", false)), "snapshot marks second seat joined")
    assert_false(bool(second_player.get("ready", true)), "snapshot marks second seat not ready before ready signal")
    assert_eq(str(second_player.get("display_name", "")), "", "snapshot includes default second seat display name")
    assert_eq(int(second_player.get("icon_id", -1)), -1, "snapshot includes default second seat icon")
    assert_eq(int(second_player.get("color_id", -1)), 1, "snapshot includes default second seat color")


func test_set_player_identity_updates_snapshot_and_rejects_color_conflict() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config, true)
    server.authorize_peer(11, "alice")
    server.authorize_peer(12, "bob")
    assert_eq(str(server.register_remote_client("demo_002", "alice", 11, null).get("reason", "")), "", "alice joins")
    assert_eq(str(server.register_remote_client("demo_002", "bob", 12, null).get("reason", "")), "", "bob joins")

    var alice_identity: Dictionary = server.rpc_set_player_identity("demo_002", "alice", "Miner Alice", 3, 3, 11)
    assert_eq(str(alice_identity.get("reason", "")), "", "alice identity accepted")
    var bob_conflict: Dictionary = server.rpc_set_player_identity("demo_002", "bob", "Miner Bob", 4, 3, 12)
    assert_eq(str(bob_conflict.get("reason", "")), "color_unavailable", "bob cannot reuse alice color")
    var bob_identity: Dictionary = server.rpc_set_player_identity("demo_002", "bob", "Miner Bob", 4, 2, 12)
    assert_eq(str(bob_identity.get("reason", "")), "", "bob identity accepted with free color")

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    var players: Array = snapshot.get("players", [])
    assert_eq(players.size(), 2, "snapshot includes both players")
    var alice: Dictionary = players[0]
    var bob: Dictionary = players[1]
    assert_eq(str(alice.get("display_name", "")), "Miner Alice", "snapshot includes alice name")
    assert_eq(int(alice.get("icon_id", -1)), 3, "snapshot includes alice icon")
    assert_eq(int(alice.get("color_id", -1)), 3, "snapshot includes alice color")
    assert_eq(str(bob.get("display_name", "")), "Miner Bob", "snapshot includes bob name")
    assert_eq(int(bob.get("icon_id", -1)), 4, "snapshot includes bob icon")
    assert_eq(int(bob.get("color_id", -1)), 2, "snapshot includes bob color")


func test_set_player_identity_accepts_last_icon_frame() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(11, "alice")
    assert_eq(str(server.register_remote_client("demo_002", "alice", 11, null).get("reason", "")), "", "alice joins")

    var identity_result: Dictionary = server.rpc_set_player_identity("demo_002", "alice", "Miner Alice", 15, 0, 11)
    assert_eq(str(identity_result.get("reason", "")), "", "last icon frame is accepted")

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    var players: Array = snapshot.get("players", [])
    assert_eq(players.size(), 2, "snapshot includes room seats")
    var alice: Dictionary = players[0]
    assert_eq(int(alice.get("icon_id", -1)), 15, "snapshot includes last icon frame")


func test_set_player_identity_rejects_invalid_identity_values() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(11, "alice")
    assert_eq(str(server.register_remote_client("demo_002", "alice", 11, null).get("reason", "")), "", "alice joins")

    var empty_name: Dictionary = server.rpc_set_player_identity("demo_002", "alice", "   ", 0, 0, 11)
    assert_eq(str(empty_name.get("reason", "")), "invalid_display_name", "empty display name rejected")

    var invalid_icon: Dictionary = server.rpc_set_player_identity("demo_002", "alice", "Miner Alice", 16, 0, 11)
    assert_eq(str(invalid_icon.get("reason", "")), "invalid_icon_id", "invalid icon rejected")

    var invalid_color: Dictionary = server.rpc_set_player_identity("demo_002", "alice", "Miner Alice", 0, 6, 11)
    assert_eq(str(invalid_color.get("reason", "")), "invalid_color_id", "invalid color rejected")


func test_sync_request_rejects_peer_player_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(11, "alice")
    var join_result: Dictionary = server.register_remote_client("demo_002", "alice", 11, null)
    assert_eq(str(join_result.get("reason", "")), "", "join succeeds")

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "bob", 11)
    assert_eq(str(sync_result.get("reason", "")), "peer_player_mismatch", "sync rejects mismatched player id")


func test_sync_request_rejects_invalid_game_id() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    server.authorize_peer(11, "alice")
    server.peer_slots[11] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }

    var sync_result: Dictionary = server.rpc_sync_request("missing_game", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "invalid_game_id", "sync rejects unknown game id")


func test_sync_request_rejects_unregistered_peer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "unregistered_peer", "sync rejects unknown peer slot")


func test_sync_snapshot_reflects_moved_pawn_state() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(11, "alice")
    server.authorize_peer(12, "bob")
    var first_join: Dictionary = server.register_remote_client("demo_002", "alice", 11, null)
    var second_join: Dictionary = server.register_remote_client("demo_002", "bob", 12, null)
    assert_eq(str(first_join.get("reason", "")), "", "first join succeeds")
    assert_eq(str(second_join.get("reason", "")), "", "second join succeeds")

    var roll_result: Dictionary = server.rpc_roll_dice("demo_002", "alice", 11)
    assert_eq(str(roll_result.get("reason", "")), "", "roll succeeds")

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    var players: Array = snapshot.get("players", [])
    assert_eq(players.size(), 2, "snapshot includes both players")
    var player_zero: Dictionary = players[0]
    assert_true(int(player_zero.get("position", 0)) > 0, "snapshot position reflects moved pawn")


func test_reconnect_sync_includes_incident_mutated_player_balances() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    var game_match = server.create_match(config)
    server.authorize_peer(11, "alice")
    server.authorize_peer(12, "bob")
    assert_eq(str(server.register_remote_client("demo_002", "alice", 11, null).get("reason", "")), "", "alice joins")
    assert_eq(str(server.register_remote_client("demo_002", "bob", 12, null).get("reason", "")), "", "bob joins")

    # Simulate bob going offline before alice triggers an incident effect.
    server.handle_peer_disconnected(12)
    assert_false(server.peer_slots.has(12), "bob peer slot removed on disconnect")

    # Alice lands on first bear incident card: -1 fiat.
    game_match._server_move_pawn(4)
    assert_true(is_equal_approx(game_match.state.players[0].fiat_balance, 119.0), "incident effect applied to alice while bob offline")

    # Bob reconnects with a new peer and requests sync snapshot.
    server.authorize_peer(22, "bob")
    var reconnect_result: Dictionary = server.register_remote_client("demo_002", "bob", 22, null)
    assert_eq(str(reconnect_result.get("reason", "")), "", "bob reconnect succeeds")
    assert_eq(int(reconnect_result.get("player_index", -1)), 1, "bob reconnect keeps player slot")

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "bob", 22)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds after reconnect")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    var players: Array = snapshot.get("players", [])
    assert_eq(players.size(), 2, "snapshot includes two players")
    if players.size() == 2:
        var alice: Dictionary = players[0]
        assert_true(is_equal_approx(float(alice.get("fiat_balance", 0.0)), 119.0), "reconnected player sees alice updated fiat balance")
        assert_true(is_equal_approx(float(alice.get("bitcoin_balance", 0.0)), 0.0), "reconnected player sees alice updated btc balance")


func test_peer_disconnect_detaches_match_client_slot() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    var game_match = server.create_match(config)
    server.authorize_peer(11, "alice")
    var join_result: Dictionary = server.register_remote_client("demo_002", "alice", 11, null)
    assert_eq(str(join_result.get("reason", "")), "", "join succeeds")
    assert_true(server.peer_slots.has(11), "peer slot exists before disconnect")
    assert_true(game_match.clients[0] != null, "client slot bound before disconnect")

    server.handle_peer_disconnected(11)

    assert_false(server.peer_slots.has(11), "peer slot removed on disconnect")
    assert_true(game_match.clients[0] == null, "disconnected peer client detached from match slot")


func test_end_turn_rejects_invalid_game_id() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var result: Dictionary = server.rpc_end_turn("missing_game", "alice", 1)
    assert_eq(str(result.get("reason", "")), "invalid_game_id", "end turn rejects invalid game id")


func test_end_turn_rejects_unregistered_peer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    var result: Dictionary = server.rpc_end_turn("demo_002", "alice", 1)
    assert_eq(str(result.get("reason", "")), "unregistered_peer", "end turn rejects unknown peer")


func test_end_turn_rejects_peer_game_id_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_003",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_end_turn("demo_002", "alice", 1)
    assert_eq(str(result.get("reason", "")), "peer_game_id_mismatch", "end turn rejects peer game mismatch")


func test_end_turn_rejects_peer_player_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_end_turn("demo_002", "bob", 1)
    assert_eq(str(result.get("reason", "")), "peer_player_mismatch", "end turn rejects peer player mismatch")


func test_buy_property_rejects_invalid_game_id() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var result: Dictionary = server.rpc_buy_property("missing_game", "alice", 6, 1)
    assert_eq(str(result.get("reason", "")), "invalid_game_id", "buy rejects invalid game id")


func test_buy_property_rejects_unregistered_peer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    var result: Dictionary = server.rpc_buy_property("demo_002", "alice", 6, 1)
    assert_eq(str(result.get("reason", "")), "unregistered_peer", "buy rejects unknown peer")


func test_buy_property_rejects_peer_game_id_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_003",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_buy_property("demo_002", "alice", 6, 1)
    assert_eq(str(result.get("reason", "")), "peer_game_id_mismatch", "buy rejects peer game mismatch")


func test_buy_property_rejects_peer_player_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_buy_property("demo_002", "bob", 6, 1)
    assert_eq(str(result.get("reason", "")), "peer_player_mismatch", "buy rejects peer player mismatch")


func test_pay_toll_rejects_invalid_game_id() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var result: Dictionary = server.rpc_pay_toll("missing_game", "alice", 1)
    assert_eq(str(result.get("reason", "")), "invalid_game_id", "pay toll rejects invalid game id")


func test_pay_toll_rejects_unregistered_peer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    var result: Dictionary = server.rpc_pay_toll("demo_002", "alice", 1)
    assert_eq(str(result.get("reason", "")), "unregistered_peer", "pay toll rejects unknown peer")


func test_pay_toll_rejects_peer_game_id_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_003",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_pay_toll("demo_002", "alice", 1)
    assert_eq(str(result.get("reason", "")), "peer_game_id_mismatch", "pay toll rejects peer game mismatch")


func test_pay_toll_rejects_peer_player_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_pay_toll("demo_002", "bob", 1)
    assert_eq(str(result.get("reason", "")), "peer_player_mismatch", "pay toll rejects peer player mismatch")


func test_buy_miner_batch_rejects_invalid_game_id() -> void:
    var server: HeadlessServer = HeadlessServer.new()
    var result: Dictionary = server.rpc_buy_miner_batch("missing_game", "alice", 6, 1)
    assert_eq(str(result.get("reason", "")), "invalid_game_id", "buy miner rejects invalid game id")


func test_buy_miner_batch_rejects_unregistered_peer() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    var result: Dictionary = server.rpc_buy_miner_batch("demo_002", "alice", 6, 1)
    assert_eq(str(result.get("reason", "")), "unregistered_peer", "buy miner rejects unknown peer")


func test_buy_miner_batch_rejects_peer_game_id_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_003",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_buy_miner_batch("demo_002", "alice", 6, 1)
    assert_eq(str(result.get("reason", "")), "peer_game_id_mismatch", "buy miner rejects peer game mismatch")


func test_buy_miner_batch_rejects_peer_player_mismatch() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.peer_slots[1] = {
        "game_id": "demo_002",
        "player_id": "alice",
        "player_index": 0,
    }
    var result: Dictionary = server.rpc_buy_miner_batch("demo_002", "bob", 6, 1)
    assert_eq(str(result.get("reason", "")), "peer_player_mismatch", "buy miner rejects peer player mismatch")


func test_sync_snapshot_includes_pending_action() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)
    server.authorize_peer(11, "alice")
    server.authorize_peer(12, "bob")
    assert_eq(str(server.register_remote_client("demo_002", "alice", 11, null).get("reason", "")), "", "alice joins")
    assert_eq(str(server.register_remote_client("demo_002", "bob", 12, null).get("reason", "")), "", "bob joins")

    assert_eq(str(server.rpc_roll_dice("demo_002", "alice", 11).get("reason", "")), "", "roll succeeds")
    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    var pending_action: Dictionary = snapshot.get("pending_action", { })
    assert_eq(str(pending_action.get("type", "")), "buy_or_end_turn", "snapshot includes pending action type")
    assert_eq(int(pending_action.get("tile_index", -1)), 6, "snapshot includes pending tile index")
    assert_true(is_equal_approx(float(pending_action.get("buy_price", 0.0)), 4.0), "snapshot includes buy price for buy_or_end_turn")


func test_sync_snapshot_includes_pay_toll_pending_action_metadata() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    var game_match = server.create_match(config)
    server.authorize_peer(11, "alice")
    server.authorize_peer(12, "bob")
    assert_eq(str(server.register_remote_client("demo_002", "alice", 11, null).get("reason", "")), "", "alice joins")
    assert_eq(str(server.register_remote_client("demo_002", "bob", 12, null).get("reason", "")), "", "bob joins")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 2
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles

    assert_eq(str(server.rpc_roll_dice("demo_002", "alice", 11).get("reason", "")), "", "roll succeeds")
    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    var pending_action: Dictionary = snapshot.get("pending_action", { })
    assert_eq(str(pending_action.get("type", "")), "pay_toll", "snapshot includes pay_toll pending action type")
    assert_eq(int(pending_action.get("tile_index", -1)), 6, "snapshot includes pay_toll tile index")
    assert_eq(int(pending_action.get("owner_index", -1)), 1, "snapshot includes pay_toll owner index")
    assert_true(is_equal_approx(float(pending_action.get("amount", 0.0)), 0.6), "snapshot includes pay_toll amount")


func test_sync_snapshot_includes_finished_match_metadata() -> void:
    var config: Config = Config.from_values("demo_002", 2, 24)
    var server: HeadlessServer = HeadlessServer.new()
    var game_match = server.create_match(config)
    server.authorize_peer(11, "alice")
    server.authorize_peer(12, "bob")
    assert_eq(str(server.register_remote_client("demo_002", "alice", 11, null).get("reason", "")), "", "alice joins")
    assert_eq(str(server.register_remote_client("demo_002", "bob", 12, null).get("reason", "")), "", "bob joins")

    var tiles: Array = game_match.board_state.get("tiles", [])
    var tile: Dictionary = tiles[6]
    tile["owner_index"] = 1
    tile["miner_batches"] = 1
    tiles[6] = tile
    game_match.board_state["tiles"] = tiles
    game_match.state.players[1].bitcoin_balance = 19.0

    assert_eq(str(server.rpc_roll_dice("demo_002", "alice", 11).get("reason", "")), "", "roll succeeds and ends match")

    var sync_result: Dictionary = server.rpc_sync_request("demo_002", "alice", 11)
    assert_eq(str(sync_result.get("reason", "")), "", "sync succeeds")
    var snapshot: Dictionary = sync_result.get("snapshot", { })
    assert_true(bool(snapshot.get("has_finished", false)), "snapshot marks match finished")
    assert_eq(int(snapshot.get("winner_index", -1)), 1, "snapshot winner index")
    assert_eq(str(snapshot.get("end_reason", "")), "btc_goal_reached", "snapshot end reason")
