extends RefCounted

## Typed runtime model for the wrapper launch handoff.
##
## This is intentionally a RefCounted data object instead of a Resource because
## the payload is transient protocol data, not editor-authored asset data.

var _token: String
var _game_id: String
var _game_server_url: String
var _player_address: String

func _init(
    token: String,
    game_id: String,
    game_server_url: String,
    player_address: String
) -> void:
    assert(token.strip_edges() != "")
    assert(game_id.strip_edges() != "")
    assert(game_server_url.strip_edges() != "")
    assert(player_address.strip_edges() != "")
    _token = token
    _game_id = game_id
    _game_server_url = game_server_url
    _player_address = player_address

func clone():
    return get_script().new(_token, _game_id, _game_server_url, _player_address)

func build_summary() -> String:
    return "\n".join([
        "Room: %s" % _game_id,
        "Server: %s" % _game_server_url,
        "Player: %s" % _player_address,
        "Token: %s" % _mask_token_presence(),
    ])

func _mask_token_presence() -> String:
    if _token.strip_edges() == "":
        return "missing"
    return "present (%d chars)" % _token.length()
