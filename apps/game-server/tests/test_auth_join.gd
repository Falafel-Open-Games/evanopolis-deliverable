extends GutTest

const Config = preload("res://scripts/config.gd")
const HeadlessServer = preload("res://scripts/server.gd")


func test_join_rejects_without_auth() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)

    var result: Dictionary = server.register_remote_client("demo_002", "alice", 1, null)

    assert_eq(str(result.get("reason", "")), "unauthorized", "join should be rejected without auth")


func test_join_accepts_after_auth() -> void:
    var config: Config = Config.new("res://configs/demo_002.toml")
    var server: HeadlessServer = HeadlessServer.new()
    server.create_match(config)

    assert_true(server.has_method("authorize_peer"), "server should expose authorize_peer for JWT auth")
    if not server.has_method("authorize_peer"):
        return

    server.call("authorize_peer", 1, "alice")
    var result: Dictionary = server.register_remote_client("demo_002", "alice", 1, null)

    assert_eq(str(result.get("reason", "")), "", "join should be accepted after auth")
