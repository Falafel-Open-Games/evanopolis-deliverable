extends "res://scripts/headless_rpc.gd"

const Config = preload("res://scripts/config.gd")
const HeadlessServer = preload("res://scripts/server.gd")

const DEFAULT_PORT: int = 9010
const DEFAULT_CONFIG_DIR: String = "res://configs"
const DEFAULT_AUTH_VERIFY_PATH: String = "/whoami"

var server: HeadlessServer
var config_paths: Array[String] = []
var port: int = DEFAULT_PORT
var auth_base_url: String = ""
var auth_verify_path: String = DEFAULT_AUTH_VERIFY_PATH


func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_args()
    _parse_args(args)
    if not _validate_auth_config():
        _exit_missing_auth_config()
        return
    _log_auth_config()
    _start_server()
    _load_matches()


func _validate_auth_config() -> bool:
    return not auth_base_url.is_empty()


func _exit_missing_auth_config() -> void:
    push_error("server: AUTH_BASE_URL is required")
    get_tree().quit(1)


func _parse_args(args: PackedStringArray) -> void:
    var index: int = 0
    var config_dir: String = DEFAULT_CONFIG_DIR
    var env_vars: Dictionary = _load_dotenv()
    auth_base_url = str(OS.get_environment("AUTH_BASE_URL"))
    if auth_base_url.is_empty() and env_vars.has("AUTH_BASE_URL"):
        auth_base_url = str(env_vars.get("AUTH_BASE_URL", ""))
    var env_verify_path: String = str(OS.get_environment("AUTH_VERIFY_PATH"))
    if env_verify_path.is_empty() and env_vars.has("AUTH_VERIFY_PATH"):
        env_verify_path = str(env_vars.get("AUTH_VERIFY_PATH", ""))
    if not env_verify_path.is_empty():
        auth_verify_path = env_verify_path
    while index < args.size():
        var arg: String = args[index]
        if arg == "--config-dir" and index + 1 < args.size():
            config_dir = args[index + 1]
            index += 2
            continue
        if arg == "--config" and index + 1 < args.size():
            config_paths.append(args[index + 1])
            index += 2
            continue
        if arg == "--port" and index + 1 < args.size():
            port = int(args[index + 1])
            index += 2
            continue
        if arg == "--auth-base-url" and index + 1 < args.size():
            auth_base_url = args[index + 1]
            index += 2
            continue
        if arg == "--auth-verify-path" and index + 1 < args.size():
            auth_verify_path = args[index + 1]
            index += 2
            continue
        index += 1
    if config_paths.is_empty():
        config_paths = _configs_from_dir(config_dir)


func _load_dotenv() -> Dictionary:
    var results: Dictionary = { }
    var paths: Array[String] = ["res://../.env", "res://.env"]
    for path in paths:
        if not FileAccess.file_exists(path):
            continue
        var file: FileAccess = FileAccess.open(path, FileAccess.READ)
        if file == null:
            continue
        while not file.eof_reached():
            var line: String = file.get_line().strip_edges()
            if line.is_empty() or line.begins_with("#"):
                continue
            var parts: PackedStringArray = line.split("=", false, 2)
            if parts.size() < 2:
                continue
            var key: String = parts[0].strip_edges()
            var value: String = parts[1].strip_edges()
            if value.begins_with("\"") and value.ends_with("\"") and value.length() >= 2:
                value = value.substr(1, value.length() - 2)
            results[key] = value
        file.close()
    return results


func _log_auth_config() -> void:
    print("server: auth verify url=%s%s" % [auth_base_url, auth_verify_path])


func _start_server() -> void:
    server = HeadlessServer.new()
    var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
    var result: int = peer.create_server(port, "0.0.0.0")
    assert(result == OK)
    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    print("server: listening on port %d" % port)


func _load_matches() -> void:
    assert(not config_paths.is_empty())
    for path in config_paths:
        var config: Config = Config.new(path)
        assert(not config.game_id.is_empty())
        assert(not server.matches.has(config.game_id))
        server.create_match(config, true)
        print("server: loaded match game_id=%s from %s" % [config.game_id, path])


func _configs_from_dir(config_dir: String) -> Array[String]:
    var results: Array[String] = []
    var dir: DirAccess = DirAccess.open(config_dir)
    assert(dir)
    dir.list_dir_begin()
    var file_name: String = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".toml"):
            results.append(config_dir.path_join(file_name))
        file_name = dir.get_next()
    dir.list_dir_end()
    results.sort()
    return results


func _on_peer_connected(peer_id: int) -> void:
    print("server: peer connected %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
    print("server: peer disconnected %d" % peer_id)
    server.handle_peer_disconnected(peer_id)


func _handle_join(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.register_remote_client(game_id, player_id, sender_id, self)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        print("server: join rejected game_id=%s player_id=%s peer=%d reason=%s" % [game_id, player_id, sender_id, reason])
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])
        return
    var replaced_peer_id: int = int(result.get("replaced_peer_id", -1))
    if replaced_peer_id > 0:
        print("server: reconnect replacing old_peer=%d new_peer=%d player_id=%s game_id=%s" % [replaced_peer_id, sender_id, player_id, game_id])
        _disconnect_peer(replaced_peer_id)
    var assigned_index: int = int(result.get("player_index", -1))
    var last_seq: int = int(result.get("last_seq", 0))
    _rpc_to_peer(sender_id, "rpc_join_accepted", [seq, player_id, assigned_index, last_seq])
    print("server: join game_id=%s player_id=%s player=%d peer=%d" % [game_id, player_id, assigned_index, sender_id])


func _handle_auth(token: String) -> void:
    var sender_id: int = _get_sender_id()
    if token.is_empty():
        _auth_fail(sender_id, "missing_token")
        return
    if auth_base_url.is_empty():
        _auth_fail(sender_id, "missing_auth_service")
        return
    _verify_token(sender_id, token)


func _handle_sync_request(game_id: String, player_id: String, last_applied_seq: int) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_sync_request(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])
        return
    var snapshot: Dictionary = result.get("snapshot", { })
    var final_seq: int = int(result.get("final_seq", 0))
    _rpc_to_peer(sender_id, "rpc_state_snapshot", [0, snapshot])
    _rpc_to_peer(sender_id, "rpc_sync_complete", [0, final_seq])
    print(
        "server: sync complete game_id=%s player_id=%s peer=%d client_last_seq=%d final_seq=%d"
        % [game_id, player_id, sender_id, last_applied_seq, final_seq],
    )


func _handle_player_ready(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_player_ready(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _verify_token(peer_id: int, token: String) -> void:
    var request: HTTPRequest = HTTPRequest.new()
    add_child(request)
    request.request_completed.connect(_on_auth_request_completed.bind(request, peer_id))
    var url: String = auth_base_url + auth_verify_path
    var headers: PackedStringArray = ["Authorization: Bearer %s" % token]
    var result: int = request.request(url, headers)
    if result != OK:
        request.queue_free()
        _auth_fail(peer_id, "auth_request_failed")


func _on_auth_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, peer_id: int) -> void:
    request.queue_free()
    if result != OK or response_code != 200:
        _auth_fail(peer_id, "unauthorized", "status=%d result=%d" % [response_code, result])
        return
    var body_text: String = body.get_string_from_utf8()
    var parsed: Variant = JSON.parse_string(body_text)
    if typeof(parsed) != TYPE_DICTIONARY:
        _auth_fail(peer_id, "invalid_auth_response")
        return
    var payload: Dictionary = parsed
    var player_id: String = str(payload.get("sub", ""))
    if player_id.is_empty():
        _auth_fail(peer_id, "missing_sub")
        return
    var exp_value: int = int(payload.get("exp", 0))
    server.authorize_peer(peer_id, player_id)
    rpc_id(peer_id, "rpc_auth_ok", player_id, exp_value)
    print("server: auth ok peer=%d player_id=%s exp=%d" % [peer_id, player_id, exp_value])


func _get_sender_id() -> int:
    return multiplayer.get_remote_sender_id()


func _rpc_to_peer(peer_id: int, method: String, args: Array = []) -> void:
    var payload: Array = [peer_id, method]
    payload.append_array(args)
    Callable(self, "rpc_id").callv(payload)


func _disconnect_peer(peer_id: int) -> void:
    var connected_peers: PackedInt32Array = multiplayer.get_peers()
    if not connected_peers.has(peer_id):
        return
    multiplayer.disconnect_peer(peer_id)


func _auth_fail(peer_id: int, reason: String, detail: String = "") -> void:
    if detail.is_empty():
        print("server: auth error peer=%d reason=%s" % [peer_id, reason])
    else:
        print("server: auth error peer=%d reason=%s %s" % [peer_id, reason, detail])
    rpc_id(peer_id, "rpc_auth_error", reason)
    _disconnect_peer(peer_id)


func _handle_roll_dice(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_roll_dice(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _handle_end_turn(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_end_turn(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _handle_buy_property(game_id: String, player_id: String, tile_index: int) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_buy_property(game_id, player_id, tile_index, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _handle_buy_miner_batch(game_id: String, player_id: String, tile_index: int) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_buy_miner_batch(game_id, player_id, tile_index, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _handle_pay_toll(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_pay_toll(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _handle_pay_inspection_fee(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_pay_inspection_fee(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _handle_roll_inspection_exit(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_roll_inspection_exit(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _handle_use_inspection_voucher(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_use_inspection_voucher(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])
