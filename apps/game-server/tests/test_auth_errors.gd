extends GutTest

const ServerMain = preload("res://scripts/server_main.gd")


class FakeHeadlessServer:
    extends "res://scripts/server.gd"

    var next_result: Dictionary = { }
    var calls: Array[Dictionary] = []
    var sync_next_result: Dictionary = { }
    var sync_calls: Array[Dictionary] = []


    func register_remote_client(game_id: String, player_id: String, peer_id: int, server_node: Node) -> Dictionary:
        calls.append(
            {
                "game_id": game_id,
                "player_id": player_id,
                "peer_id": peer_id,
                "server_node": server_node,
            },
        )
        return next_result


    func rpc_sync_request(game_id: String, player_id: String, sender_peer_id: int = -1) -> Dictionary:
        sync_calls.append(
            {
                "game_id": game_id,
                "player_id": player_id,
                "sender_peer_id": sender_peer_id,
            },
        )
        return sync_next_result


class ServerMainDouble:
    extends "res://scripts/server_main.gd"

    var last_error_reason: String = ""
    var last_error_detail: String = ""
    var disconnects: Array[int] = []
    var sender_id: int = 1
    var verify_called: bool = false
    var rpc_calls: Array[Dictionary] = []


    func _ready() -> void:
        pass


    func _get_sender_id() -> int:
        return sender_id


    func _disconnect_peer(peer_id: int) -> void:
        disconnects.append(peer_id)


    func _auth_fail(peer_id: int, reason: String, detail: String = "") -> void:
        last_error_reason = reason
        last_error_detail = detail
        _disconnect_peer(peer_id)


    func _verify_token(peer_id: int, token: String) -> void:
        verify_called = true


    func _rpc_to_peer(peer_id: int, method: String, args: Array = []) -> void:
        rpc_calls.append(
            {
                "peer_id": peer_id,
                "method": method,
                "args": args,
            },
        )


func test_auth_missing_token_logs_error() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    server.auth_base_url = "http://127.0.0.1:3000"
    server._handle_auth("")
    assert_eq(server.last_error_reason, "missing_token", "missing token is rejected")
    assert_eq(server.disconnects.size(), 1, "peer disconnected")
    assert_eq(server.verify_called, false, "verification not attempted")


func test_auth_missing_service_logs_error() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    server.auth_base_url = ""
    server._handle_auth("token")
    assert_eq(server.last_error_reason, "missing_auth_service", "missing auth service rejected")
    assert_eq(server.disconnects.size(), 1, "peer disconnected")
    assert_eq(server.verify_called, false, "verification not attempted")


func test_auth_unauthorized_response_logs_error() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    var request: HTTPRequest = HTTPRequest.new()
    add_child_autofree(request)
    server._on_auth_request_completed(ERR_CANT_CONNECT, 401, [], PackedByteArray(), request, 2)
    assert_eq(server.last_error_reason, "unauthorized", "unauthorized response rejected")
    assert_eq(server.disconnects.size(), 1, "peer disconnected")


func test_auth_invalid_response_logs_error() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    var request: HTTPRequest = HTTPRequest.new()
    add_child_autofree(request)
    var body: PackedByteArray = "[]".to_utf8_buffer()
    server._on_auth_request_completed(OK, 200, [], body, request, 3)
    assert_eq(server.last_error_reason, "invalid_auth_response", "invalid response rejected")
    assert_eq(server.disconnects.size(), 1, "peer disconnected")


func test_auth_missing_sub_logs_error() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    var request: HTTPRequest = HTTPRequest.new()
    add_child_autofree(request)
    var body: PackedByteArray = "{}".to_utf8_buffer()
    server._on_auth_request_completed(OK, 200, [], body, request, 4)
    assert_eq(server.last_error_reason, "missing_sub", "missing sub rejected")
    assert_eq(server.disconnects.size(), 1, "peer disconnected")


func test_join_reconnect_disconnects_replaced_peer() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    var fake_headless_server: FakeHeadlessServer = FakeHeadlessServer.new()
    fake_headless_server.next_result = {
        "reason": "",
        "seq": 0,
        "player_index": 0,
        "last_seq": 7,
        "replaced_peer_id": 11,
    }
    server.server = fake_headless_server
    server.sender_id = 22

    server._handle_join("demo_002", "alice")

    assert_eq(fake_headless_server.calls.size(), 1, "join is forwarded to server registration")
    var call: Dictionary = fake_headless_server.calls[0]
    assert_eq(str(call.get("game_id", "")), "demo_002", "game id forwarded")
    assert_eq(str(call.get("player_id", "")), "alice", "player id forwarded")
    assert_eq(int(call.get("peer_id", -1)), 22, "sender peer id forwarded")
    assert_eq(server.disconnects.size(), 1, "old peer is disconnected on reconnect")
    assert_eq(server.disconnects[0], 11, "replaced peer is disconnected")


func test_sync_request_sends_snapshot_and_sync_complete() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    var fake_headless_server: FakeHeadlessServer = FakeHeadlessServer.new()
    fake_headless_server.sync_next_result = {
        "reason": "",
        "seq": 0,
        "snapshot": {
            "game_id": "demo_002",
            "turn_number": 2,
            "current_player_index": 1,
            "current_cycle": 1,
            "board_state": {
                "size": 24,
                "tiles": [],
            },
            "players": [],
        },
        "final_seq": 14,
    }
    server.server = fake_headless_server
    server.sender_id = 22

    server._handle_sync_request("demo_002", "alice", 8)

    assert_eq(fake_headless_server.sync_calls.size(), 1, "sync request forwarded to server")
    var sync_call: Dictionary = fake_headless_server.sync_calls[0]
    assert_eq(int(sync_call.get("sender_peer_id", -1)), 22, "sender peer id forwarded for sync")
    assert_eq(server.rpc_calls.size(), 2, "snapshot and sync complete are sent to client")
    assert_eq(str(server.rpc_calls[0].get("method", "")), "rpc_state_snapshot", "snapshot sent first")
    assert_eq(str(server.rpc_calls[1].get("method", "")), "rpc_sync_complete", "sync complete sent second")
    var sync_complete_args: Array = server.rpc_calls[1].get("args", [])
    assert_eq(int(sync_complete_args[1]), 14, "final sequence forwarded to client")


func test_sync_request_rejection_sends_action_rejected() -> void:
    var server: ServerMainDouble = ServerMainDouble.new()
    add_child_autofree(server)
    var fake_headless_server: FakeHeadlessServer = FakeHeadlessServer.new()
    fake_headless_server.sync_next_result = {
        "reason": "peer_player_mismatch",
        "seq": 0,
    }
    server.server = fake_headless_server
    server.sender_id = 22

    server._handle_sync_request("demo_002", "alice", 8)

    assert_eq(server.rpc_calls.size(), 1, "rejected sync sends only one rpc")
    assert_eq(str(server.rpc_calls[0].get("method", "")), "rpc_action_rejected", "sync rejection sends action rejected")
