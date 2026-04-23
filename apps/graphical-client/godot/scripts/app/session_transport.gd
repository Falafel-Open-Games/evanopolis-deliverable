extends Node

signal connected()
signal connection_failed()
signal server_disconnected()

var _websocket_peer: WebSocketMultiplayerPeer

func connect_to_server(game_server_url: String) -> void:
    assert(game_server_url.strip_edges() != "")

    _disconnect_multiplayer_signals()
    _websocket_peer = WebSocketMultiplayerPeer.new()
    var result: int = _websocket_peer.create_client(game_server_url)
    if result != OK:
        connection_failed.emit()
        return

    multiplayer.multiplayer_peer = _websocket_peer
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func disconnect_transport() -> void:
    _disconnect_multiplayer_signals()
    if multiplayer.multiplayer_peer == _websocket_peer:
        multiplayer.multiplayer_peer = null
    _websocket_peer = null

func _on_connected_to_server() -> void:
    connected.emit()

func _on_connection_failed() -> void:
    connection_failed.emit()

func _on_server_disconnected() -> void:
    server_disconnected.emit()

func _disconnect_multiplayer_signals() -> void:
    if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
        multiplayer.connected_to_server.disconnect(_on_connected_to_server)
    if multiplayer.connection_failed.is_connected(_on_connection_failed):
        multiplayer.connection_failed.disconnect(_on_connection_failed)
    if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
        multiplayer.server_disconnected.disconnect(_on_server_disconnected)
