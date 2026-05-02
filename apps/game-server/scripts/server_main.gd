extends "res://scripts/headless_rpc.gd"

const HeadlessServer = preload("res://scripts/server.gd")
const MatchPersistence = preload("res://scripts/match_persistence.gd")
const RoomDefinitionLoader = preload("res://scripts/room_definition_loader.gd")

const DEFAULT_PORT: int = 9010
const DEFAULT_AUTH_VERIFY_PATH: String = "/whoami"
const DEFAULT_ROOMS_API_LOOKUP_TEMPLATE: String = "/v0/rooms/%s"

var server: HeadlessServer
var port: int = DEFAULT_PORT
var auth_base_url: String = ""
var auth_verify_path: String = DEFAULT_AUTH_VERIFY_PATH
var rooms_api_base_url: String = ""
var rooms_api_lookup_template: String = DEFAULT_ROOMS_API_LOOKUP_TEMPLATE
var match_state_dir: String = "user://match_state"
var pending_room_lookups: Dictionary = { }


func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_args()
    _parse_args(args)
    if not _validate_auth_config():
        _exit_missing_auth_config()
        return
    _log_auth_config()
    _start_server()


func _validate_auth_config() -> bool:
    return not auth_base_url.is_empty()


func _exit_missing_auth_config() -> void:
    push_error("server: AUTH_BASE_URL is required")
    get_tree().quit(1)


func _parse_args(args: PackedStringArray) -> void:
    var index: int = 0
    var env_vars: Dictionary = _load_dotenv()
    auth_base_url = str(OS.get_environment("AUTH_BASE_URL"))
    if auth_base_url.is_empty() and env_vars.has("AUTH_BASE_URL"):
        auth_base_url = str(env_vars.get("AUTH_BASE_URL", ""))
    var env_verify_path: String = str(OS.get_environment("AUTH_VERIFY_PATH"))
    if env_verify_path.is_empty() and env_vars.has("AUTH_VERIFY_PATH"):
        env_verify_path = str(env_vars.get("AUTH_VERIFY_PATH", ""))
    if not env_verify_path.is_empty():
        auth_verify_path = env_verify_path
    rooms_api_base_url = str(OS.get_environment("ROOMS_API_BASE_URL"))
    if rooms_api_base_url.is_empty() and env_vars.has("ROOMS_API_BASE_URL"):
        rooms_api_base_url = str(env_vars.get("ROOMS_API_BASE_URL", ""))
    var env_rooms_lookup_template: String = str(OS.get_environment("ROOMS_API_LOOKUP_TEMPLATE"))
    if env_rooms_lookup_template.is_empty() and env_vars.has("ROOMS_API_LOOKUP_TEMPLATE"):
        env_rooms_lookup_template = str(env_vars.get("ROOMS_API_LOOKUP_TEMPLATE", ""))
    if not env_rooms_lookup_template.is_empty():
        rooms_api_lookup_template = env_rooms_lookup_template
    var env_match_state_dir: String = str(OS.get_environment("MATCH_STATE_DIR"))
    if env_match_state_dir.is_empty() and env_vars.has("MATCH_STATE_DIR"):
        env_match_state_dir = str(env_vars.get("MATCH_STATE_DIR", ""))
    if not env_match_state_dir.is_empty():
        match_state_dir = env_match_state_dir
    while index < args.size():
        var arg: String = args[index]
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
        if arg == "--rooms-api-base-url" and index + 1 < args.size():
            rooms_api_base_url = args[index + 1]
            index += 2
            continue
        if arg == "--rooms-api-lookup-template" and index + 1 < args.size():
            rooms_api_lookup_template = args[index + 1]
            index += 2
            continue
        if arg == "--match-state-dir" and index + 1 < args.size():
            match_state_dir = args[index + 1]
            index += 2
            continue
        index += 1


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
    if not rooms_api_base_url.is_empty():
        print("server: rooms api lookup url=%s%s" % [rooms_api_base_url, rooms_api_lookup_template % ["<game_id>"]])
    print("server: match state dir=%s" % match_state_dir)


func _start_server() -> void:
    server = HeadlessServer.new()
    server.match_persistence = MatchPersistence.new(match_state_dir)
    var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
    var result: int = peer.create_server(port, "0.0.0.0")
    assert(result == OK)
    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    print("server: listening on port %d" % port)


func _on_peer_connected(peer_id: int) -> void:
    print("server: peer connected %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
    print("server: peer disconnected %d" % peer_id)
    server.handle_peer_disconnected(peer_id)
    _remove_pending_join_waiter(peer_id)


func _handle_join(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    if _maybe_queue_room_lookup(game_id, player_id, sender_id):
        return
    _complete_join(game_id, player_id, sender_id)


func _complete_join(game_id: String, player_id: String, sender_id: int) -> void:
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

func _handle_set_player_identity(
        game_id: String,
        player_id: String,
        display_name: String,
        icon_id: int,
        color_id: int,
) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_set_player_identity(game_id, player_id, display_name, icon_id, color_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])


func _maybe_queue_room_lookup(game_id: String, player_id: String, peer_id: int) -> bool:
    if server.matches.has(game_id):
        return false
    if rooms_api_base_url.is_empty():
        return false
    _enqueue_room_lookup_waiter(game_id, player_id, peer_id)
    if pending_room_lookups[game_id].get("request_started", false):
        return true
    return _start_room_lookup_request(game_id)


func _rooms_api_lookup_url(game_id: String) -> String:
    return rooms_api_base_url + (rooms_api_lookup_template % [game_id])


func _enqueue_room_lookup_waiter(game_id: String, player_id: String, peer_id: int) -> void:
    if not pending_room_lookups.has(game_id):
        pending_room_lookups[game_id] = {
            "waiters": [],
            "request_started": false,
            "request": null,
        }
    var state: Dictionary = pending_room_lookups[game_id]
    var waiters: Array = state.get("waiters", [])
    for waiter_variant in waiters:
        var waiter: Dictionary = waiter_variant
        if int(waiter.get("peer_id", -1)) == peer_id:
            return
    waiters.append(
        {
            "peer_id": peer_id,
            "player_id": player_id,
        },
    )
    state["waiters"] = waiters
    pending_room_lookups[game_id] = state


func _start_room_lookup_request(game_id: String) -> bool:
    var state: Dictionary = pending_room_lookups[game_id]
    var request: HTTPRequest = HTTPRequest.new()
    add_child(request)
    request.request_completed.connect(_on_room_lookup_request_completed.bind(game_id, request))
    var url: String = _rooms_api_lookup_url(game_id)
    state["request_started"] = true
    state["request"] = request
    pending_room_lookups[game_id] = state
    print("server: rooms api lookup request game_id=%s url=%s" % [game_id, url])
    var result: int = request.request(url, ["Accept: application/json"])
    if result != OK:
        request.queue_free()
        _reject_pending_room_lookup(game_id, "invalid_game_id", "request=%d url=%s" % [result, url])
    return true


func _on_room_lookup_request_completed(
        result: int,
        response_code: int,
        _headers: PackedStringArray,
        body: PackedByteArray,
        game_id: String,
        request: HTTPRequest,
) -> void:
    request.queue_free()
    var body_text: String = body.get_string_from_utf8()
    print(
        "server: rooms api lookup response game_id=%s status=%d result=%d body=%s"
        % [game_id, response_code, result, _log_preview(body_text)],
    )
    if result != OK or response_code != 200:
        _reject_pending_room_lookup(game_id, "invalid_game_id", "status=%d result=%d" % [response_code, result])
        return
    var parsed: Variant = JSON.parse_string(body_text)
    if typeof(parsed) != TYPE_DICTIONARY:
        _reject_pending_room_lookup(game_id, "invalid_room_definition", "body=%s" % _log_preview(body_text))
        return
    var room_definition: Dictionary = parsed
    var hydrate_reason: String = RoomDefinitionLoader.hydrate_match(server, game_id, room_definition, true)
    if not hydrate_reason.is_empty():
        _reject_pending_room_lookup(game_id, hydrate_reason, "body=%s" % _log_preview(body_text))
        return
    print("server: loaded match game_id=%s from rooms api" % game_id)
    _complete_pending_room_lookup(game_id)


func _complete_pending_room_lookup(game_id: String) -> void:
    if not pending_room_lookups.has(game_id):
        return
    var state: Dictionary = pending_room_lookups.get(game_id, { })
    var waiters: Array = state.get("waiters", [])
    pending_room_lookups.erase(game_id)
    for waiter_variant in waiters:
        var waiter: Dictionary = waiter_variant
        var peer_id: int = int(waiter.get("peer_id", -1))
        var player_id: String = str(waiter.get("player_id", ""))
        if peer_id <= 0:
            continue
        if not multiplayer.get_peers().has(peer_id):
            continue
        _complete_join(game_id, player_id, peer_id)


func _reject_pending_room_lookup(game_id: String, reason: String, detail: String = "") -> void:
    if not detail.is_empty():
        print("server: rooms api lookup error game_id=%s reason=%s %s" % [game_id, reason, detail])
    else:
        print("server: rooms api lookup error game_id=%s reason=%s" % [game_id, reason])
    if not pending_room_lookups.has(game_id):
        return
    var state: Dictionary = pending_room_lookups.get(game_id, { })
    var waiters: Array = state.get("waiters", [])
    pending_room_lookups.erase(game_id)
    for waiter_variant in waiters:
        var waiter: Dictionary = waiter_variant
        var peer_id: int = int(waiter.get("peer_id", -1))
        if peer_id <= 0:
            continue
        if not multiplayer.get_peers().has(peer_id):
            continue
        _rpc_to_peer(peer_id, "rpc_action_rejected", [0, reason])


func _remove_pending_join_waiter(peer_id: int) -> void:
    var game_ids: Array = pending_room_lookups.keys()
    for game_id_variant in game_ids:
        var game_id: String = str(game_id_variant)
        var state: Dictionary = pending_room_lookups.get(game_id, { })
        var waiters: Array = state.get("waiters", [])
        var filtered_waiters: Array = []
        for waiter_variant in waiters:
            var waiter: Dictionary = waiter_variant
            if int(waiter.get("peer_id", -1)) == peer_id:
                continue
            filtered_waiters.append(waiter)
        if filtered_waiters.is_empty():
            pending_room_lookups.erase(game_id)
            continue
        state["waiters"] = filtered_waiters
        pending_room_lookups[game_id] = state


func _verify_token(peer_id: int, token: String) -> void:
    var request: HTTPRequest = HTTPRequest.new()
    add_child(request)
    request.request_completed.connect(_on_auth_request_completed.bind(request, peer_id))
    var url: String = auth_base_url + auth_verify_path
    var headers: PackedStringArray = ["Authorization: Bearer %s" % token]
    print("server: auth verify request peer=%d url=%s" % [peer_id, url])
    var result: int = request.request(url, headers)
    if result != OK:
        request.queue_free()
        _auth_fail(peer_id, "auth_request_failed", "request=%d url=%s" % [result, url])


func _on_auth_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, peer_id: int) -> void:
    request.queue_free()
    var body_text: String = body.get_string_from_utf8()
    print(
        "server: auth verify response peer=%d status=%d result=%d body=%s"
        % [peer_id, response_code, result, _log_preview(body_text)],
    )
    if result != OK or response_code != 200:
        _auth_fail(peer_id, "unauthorized", "status=%d result=%d" % [response_code, result])
        return
    var parsed: Variant = JSON.parse_string(body_text)
    if typeof(parsed) != TYPE_DICTIONARY:
        _auth_fail(peer_id, "invalid_auth_response", "body=%s" % _log_preview(body_text))
        return
    var payload: Dictionary = parsed
    var player_id: String = str(payload.get("sub", ""))
    if player_id.is_empty():
        _auth_fail(peer_id, "missing_sub", "body=%s" % _log_preview(body_text))
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


func _log_preview(value: String, max_length: int = 200) -> String:
    if value.length() <= max_length:
        return value
    return "%s..." % value.substr(0, max_length)


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


func _handle_pay_toll(game_id: String, player_id: String) -> void:
    var sender_id: int = _get_sender_id()
    var result: Dictionary = server.rpc_pay_toll(game_id, player_id, sender_id)
    var reason: String = str(result.get("reason", ""))
    var seq: int = int(result.get("seq", 0))
    if not reason.is_empty():
        _rpc_to_peer(sender_id, "rpc_action_rejected", [seq, reason])
