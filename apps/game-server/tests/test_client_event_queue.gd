extends GutTest

const ClientMain = preload("res://scripts/client_main.gd")


class ClientMainDouble:
    extends "res://scripts/client_main.gd"

    var server_calls: Array[Dictionary] = []
    var server_messages: Array[String] = []
    var prompt_messages: Array[String] = []
    var note_messages: Array[String] = []
    var exit_codes: Array[int] = []
    var next_buy_choice: bool = false
    var next_buy_choices: Array[bool] = []
    var turn_prompt_count: int = 0
    var buy_prompt_count: int = 0
    var pay_toll_prompt_count: int = 0


    func _rpc_to_server(method: String, args: Array = []) -> void:
        server_calls.append(
            {
                "method": method,
                "args": args,
            },
        )


    func _start_turn_prompt() -> void:
        turn_prompt_count += 1


    func _start_buy_or_end_turn_prompt(tile_index: int, city: String, buy_price: float) -> void:
        buy_prompt_count += 1
        var available_fiat: float = float(player_fiat_balances.get(player_index, 0.0))
        _log_prompt(
            "buy property on tile=%d city=%s price=%.2f fiat=%.2f? [y/n]"
            % [tile_index, city, buy_price, available_fiat],
        )
        if next_buy_choice:
            _request_buy_property(tile_index)
            return
        _request_end_turn()


    func _start_pay_toll_prompt(tile_index: int, city: String, owner_index: int, amount: float) -> void:
        pay_toll_prompt_count += 1
        _request_pay_toll()


    func _wait_for_buy_choice() -> bool:
        if not next_buy_choices.is_empty():
            var scripted_choice: bool = next_buy_choices[0]
            next_buy_choices.remove_at(0)
            return scripted_choice
        return next_buy_choice


    func _log_server(message: String) -> void:
        server_messages.append(message)


    func _log_prompt(message: String) -> void:
        prompt_messages.append(message)


    func _log_note(message: String) -> void:
        note_messages.append(message)


    func _exit_with_code(code: int) -> void:
        exit_codes.append(code)


func test_join_requests_snapshot_sync_and_drops_pre_sync_events() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "pending"

    client._handle_game_started(3, "demo_002")
    client._handle_turn_started(4, 0, 1, 1)

    assert_eq(client.pending_events.size(), 2, "events queue before join acceptance")

    client._handle_join_accepted(0, "p2", 1, 4)
    assert_eq(client.sync_in_progress, true, "join accepted enters sync mode")
    assert_eq(client.server_calls.size(), 1, "client requests sync after join acceptance")
    assert_eq(str(client.server_calls[0].get("method", "")), "rpc_sync_request", "sync request rpc emitted")

    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 2,
            "current_player_index": 1,
            "current_cycle": 1,
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "has_started": true,
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.pending_events.size(), 0, "stale queued events dropped after snapshot sync")
    assert_eq(client.game_id, "demo_002", "game id updated from snapshot")
    assert_eq(client.current_player_index, 1, "current player updated from snapshot")
    assert_eq(client.next_expected_seq, 5, "next sequence advanced to sync final seq")
    assert_eq(client.sync_in_progress, false, "sync mode exits after sync complete")
    assert_eq(client.pending_game_started, false, "no pending game started after flush")

    client.free()


func test_sync_complete_flushes_live_events_queued_during_sync() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 0)
    assert_eq(client.sync_in_progress, true, "sync mode started")

    client._handle_turn_started(5, 0, 2, 1)
    assert_eq(client.pending_events.size(), 1, "live event queued while sync is in progress")

    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 2,
            "current_player_index": 1,
            "current_cycle": 1,
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "has_started": true,
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.pending_events.size(), 0, "queued live events flushed after sync")
    assert_eq(client.current_player_index, 0, "queued turn event applied after sync complete")
    assert_eq(client.next_expected_seq, 6, "next sequence moved past flushed event")
    assert_eq(client.sync_in_progress, false, "sync mode exited")

    client.free()


func test_queue_event_ignores_sequences_older_than_next_expected() -> void:
    var client: ClientMain = ClientMain.new()
    client.player_index = 0
    client.next_expected_seq = 6

    client._handle_turn_started(5, 1, 3, 1)

    assert_eq(client.pending_events.size(), 0, "stale event is ignored")
    assert_eq(client.current_player_index, 0, "stale event is not applied")

    client.free()


func test_state_snapshot_logs_with_players_present() -> void:
    var client: ClientMain = ClientMain.new()

    client._apply_state_snapshot(
        {
            "game_id": "demo_002",
            "turn_number": 3,
            "current_player_index": 1,
            "current_cycle": 2,
            "has_started": true,
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "players": [
                {
                    "player_index": 0,
                    "player_id": "p0",
                    "joined": true,
                    "ready": false,
                    "display_name": "Miner One",
                    "icon_id": 4,
                    "color_id": 2,
                    "position": 6,
                    "laps": 0,
                    "fiat_balance": 20.0,
                    "bitcoin_balance": 0.5,
                    "in_inspection": false,
                },
                {
                    "player_index": 1,
                    "player_id": "p1",
                    "joined": true,
                    "ready": false,
                    "display_name": "Miner Two",
                    "icon_id": 5,
                    "color_id": 3,
                    "position": 3,
                    "laps": 1,
                    "fiat_balance": 16.0,
                    "bitcoin_balance": 0.25,
                    "in_inspection": true,
                },
            ],
        },
    )

    assert_eq(client.game_id, "demo_002", "snapshot applies game id")
    assert_eq(client.current_player_index, 1, "snapshot applies current player")
    assert_eq(int(client.board_state.get("size", 0)), 18, "snapshot applies board state")
    assert_eq(str(client.player_display_names.get(0, "")), "Miner One", "snapshot applies first player display name")
    assert_eq(int(client.player_icon_ids.get(0, -1)), 4, "snapshot applies first player icon")
    assert_eq(int(client.player_color_ids.get(0, -1)), 2, "snapshot applies first player color")
    assert_eq(str(client.player_display_names.get(1, "")), "Miner Two", "snapshot applies second player display name")
    assert_eq(int(client.player_icon_ids.get(1, -1)), 5, "snapshot applies second player icon")
    assert_eq(int(client.player_color_ids.get(1, -1)), 3, "snapshot applies second player color")

    client.free()


func test_connection_failed_exits_client_process() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()

    client._on_connection_failed()

    assert_eq(client.exit_codes.size(), 1, "connection failure should trigger process exit")
    if client.exit_codes.size() == 1:
        assert_eq(client.exit_codes[0], 1, "connection failure exits with code 1")

    client.free()


func test_server_disconnected_exits_client_process() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()

    client._on_server_disconnected()

    assert_eq(client.exit_codes.size(), 1, "server disconnection should trigger process exit")
    if client.exit_codes.size() == 1:
        assert_eq(client.exit_codes[0], 1, "server disconnection exits with code 1")

    client.free()


func test_turn_started_logs_connected_players_balances_and_holdings() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client._apply_state_snapshot(
        {
            "game_id": "demo_002",
            "turn_number": 3,
            "current_player_index": 1,
            "current_cycle": 2,
            "has_started": true,
            "board_state": {
                "size": 18,
                "tiles": [
                    {
                        "index": 1,
                        "tile_type": "property",
                        "city": "Irkutsk",
                        "owner_index": 0,
                        "miner_batches": 2,
                    },
                    {
                        "index": 2,
                        "tile_type": "property",
                        "city": "Irkutsk",
                        "owner_index": 0,
                        "miner_batches": 1,
                    },
                    {
                        "index": 6,
                        "tile_type": "property",
                        "city": "Patagonia",
                        "owner_index": 1,
                        "miner_batches": 4,
                    },
                ],
            },
            "players": [
                {
                    "player_index": 0,
                    "player_id": "p0",
                    "joined": true,
                    "ready": false,
                    "position": 6,
                    "laps": 0,
                    "fiat_balance": 20.0,
                    "bitcoin_balance": 0.5,
                    "in_inspection": false,
                },
                {
                    "player_index": 1,
                    "player_id": "p1",
                    "joined": true,
                    "ready": false,
                    "position": 3,
                    "laps": 1,
                    "fiat_balance": 16.0,
                    "bitcoin_balance": 0.25,
                    "in_inspection": false,
                },
            ],
        },
    )

    client._apply_player_balance_changed(1, -2.5, 0.125, "test_adjustment")
    client._apply_turn_started(1, 4, 2)

    assert_true(client.server_messages.size() > 0, "expected server log messages")
    var last_message: String = client.server_messages[client.server_messages.size() - 1]
    assert_eq(
        last_message,
        "\u001b[32mturn started\u001b[0m: player=1, turn=4, cycle=2, connected_players=[p0(tile=6 fiat=\u001b[1m\u001b[33m20.00\u001b[0m btc=\u001b[33m0.50000000\u001b[0m properties=2), p1(tile=3 fiat=\u001b[1m\u001b[33m13.50\u001b[0m btc=\u001b[33m0.37500000\u001b[0m properties=1)]",
        "turn started includes green label and connected players tile/balance/properties",
    )

    client.free()


func test_turn_started_logs_ansi_formatting_for_negative_fiat_and_large_btc() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client._apply_state_snapshot(
        {
            "game_id": "demo_002",
            "turn_number": 4,
            "current_player_index": 1,
            "current_cycle": 2,
            "has_started": true,
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "players": [
                {
                    "player_index": 0,
                    "player_id": "p0",
                    "joined": true,
                    "ready": false,
                    "position": 9,
                    "laps": 0,
                    "fiat_balance": -1.25,
                    "bitcoin_balance": 12.3456789,
                    "in_inspection": false,
                },
                {
                    "player_index": 1,
                    "player_id": "p1",
                    "joined": true,
                    "ready": false,
                    "position": 14,
                    "laps": 1,
                    "fiat_balance": 999.99,
                    "bitcoin_balance": 0.0,
                    "in_inspection": false,
                },
            ],
        },
    )

    client._apply_turn_started(1, 4, 2)

    assert_true(client.server_messages.size() > 0, "expected server log messages")
    var last_message: String = client.server_messages[client.server_messages.size() - 1]
    assert_eq(
        last_message,
        "\u001b[32mturn started\u001b[0m: player=1, turn=4, cycle=2, connected_players=[p0(tile=9 fiat=\u001b[1m\u001b[33m-1.25\u001b[0m btc=\u001b[33m12.34567890\u001b[0m properties=0), p1(tile=14 fiat=\u001b[1m\u001b[33m999.99\u001b[0m btc=\u001b[33m0.00000000\u001b[0m properties=0)]",
        "turn started keeps ansi formatting for negative fiat and large btc balances",
    )

    client.free()


func test_game_started_logs_green_label() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client._apply_game_started("demo_002")

    assert_true(client.server_messages.size() > 0, "expected server log messages")
    var last_message: String = client.server_messages[client.server_messages.size() - 1]
    assert_eq(
        last_message,
        "\u001b[32mgame started\u001b[0m: game_id=demo_002",
        "game started includes green label",
    )

    client.free()


func test_turn_started_logs_purchase_balance_after_property_acquired() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client._apply_state_snapshot(
        {
            "game_id": "demo_002",
            "turn_number": 1,
            "current_player_index": 0,
            "current_cycle": 1,
            "has_started": true,
            "board_state": {
                "size": 18,
                "tiles": [
                    {
                        "index": 6,
                        "tile_type": "property",
                        "city": "Patagonia",
                        "owner_index": -1,
                        "miner_batches": 0,
                    },
                ],
            },
            "players": [
                {
                    "player_index": 0,
                    "player_id": "p0",
                    "joined": true,
                    "ready": false,
                    "position": 6,
                    "laps": 0,
                    "fiat_balance": 20.0,
                    "bitcoin_balance": 0.0,
                    "in_inspection": false,
                },
                {
                    "player_index": 1,
                    "player_id": "p1",
                    "joined": true,
                    "ready": false,
                    "position": 0,
                    "laps": 0,
                    "fiat_balance": 20.0,
                    "bitcoin_balance": 0.0,
                    "in_inspection": false,
                },
            ],
        },
    )

    client._apply_property_acquired(0, 6, 4.0)
    client._apply_turn_started(1, 1, 1)

    assert_true(client.server_messages.size() > 0, "expected server log messages")
    var last_message: String = client.server_messages[client.server_messages.size() - 1]
    assert_eq(
        last_message,
        "\u001b[32mturn started\u001b[0m: player=1, turn=1, cycle=1, connected_players=[p0(tile=6 fiat=\u001b[1m\u001b[33m16.00\u001b[0m btc=\u001b[33m0.00000000\u001b[0m properties=1), p1(tile=0 fiat=\u001b[1m\u001b[33m20.00\u001b[0m btc=\u001b[33m0.00000000\u001b[0m properties=0)]",
        "turn started summary reflects fiat deduction and player tile indexes",
    )

    client.free()


func test_tile_landed_uses_board_state_details() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client.current_player_index = 1
    var board: Dictionary = {
        "size": 18,
        "tiles": [
            {
                "index": 0,
                "tile_type": "start",
                "city": "",
                "incident_kind": "",
                "owner_index": -1,
                "miner_batches": 0,
            },
            {
                "index": 1,
                "tile_type": "property",
                "city": "Irkutsk",
                "incident_kind": "",
                "owner_index": -1,
                "miner_batches": 0,
            },
        ],
    }

    client._apply_board_state(board)
    client._apply_tile_landed(1, "property", "Irkutsk", -1, 0.0, 8.0, "buy_or_end_turn")
    var tile_info: Dictionary = client._tile_info_from_index(1)

    assert_eq(int(client.board_state.get("size", 0)), 18, "board state should be applied")
    assert_eq(client.board_state.get("tiles", []).size(), 2, "board tiles should be available for lookup")
    assert_eq(str(tile_info.get("tile_type", "")), "property", "tile type should resolve from board state")
    assert_eq(str(tile_info.get("city", "")), "Irkutsk", "city should resolve from board state")

    client.free()


func test_tile_landed_buy_prompt_submits_buy_property() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client.current_player_index = 0
    client.next_buy_choice = true
    client.player_fiat_balances[0] = 30.0

    client._apply_tile_landed(6, "property", "Patagonia", -1, 0.0, 3.0, "buy_or_end_turn")

    assert_eq(client.server_calls.size(), 1, "buy prompt sends one rpc")
    assert_eq(str(client.server_calls[0].get("method", "")), "rpc_buy_property", "buy path sends buy_property rpc")
    assert_eq(client.prompt_messages.size(), 1, "buy prompt logged once")
    assert_eq(client.prompt_messages[0], "buy property on tile=6 city=Patagonia price=3.00 fiat=30.00? [y/n]", "buy prompt includes buy price and current fiat")
    var args: Array = client.server_calls[0].get("args", [])
    assert_eq(int(args[2]), 6, "tile index is forwarded for buy")
    client.free()


func test_tile_landed_buy_prompt_submits_end_turn() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client.current_player_index = 0
    client.next_buy_choice = false

    client._apply_tile_landed(6, "property", "Patagonia", -1, 0.0, 3.0, "buy_or_end_turn")

    assert_eq(client.server_calls.size(), 1, "decline buy sends one rpc")
    assert_eq(str(client.server_calls[0].get("method", "")), "rpc_end_turn", "decline path sends end_turn rpc")
    client.free()


func test_tile_landed_pay_toll_prompt_submits_pay_toll() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client.current_player_index = 0

    client._apply_tile_landed(13, "property", "El Salvador", 1, 0.75, 0.0, "pay_toll")

    assert_eq(client.server_calls.size(), 1, "pay toll prompt sends one rpc")
    assert_eq(str(client.server_calls[0].get("method", "")), "rpc_pay_toll", "pay toll path sends pay_toll rpc")
    client.free()


func test_tile_landed_pay_toll_for_other_player_does_not_prompt() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 1
    client.current_player_index = 0

    client._apply_tile_landed(13, "property", "El Salvador", 1, 0.75, 0.0, "pay_toll")

    assert_eq(client.server_calls.size(), 0, "no rpc sent when pay_toll is for another player")
    assert_eq(client.pay_toll_prompt_count, 0, "no pay toll prompt for another player")
    client.free()


func test_sync_complete_prompts_roll_when_snapshot_has_current_player_turn() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 4)
    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 3,
            "current_player_index": 1,
            "current_cycle": 1,
            "pending_action": { },
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "has_started": true,
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.turn_prompt_count, 1, "sync resume prompts roll for current player")
    assert_eq(client.buy_prompt_count, 0, "no buy prompt when there is no pending action")
    assert_eq(client.pay_toll_prompt_count, 0, "no pay toll prompt when there is no pending action")
    client.free()


func test_sync_complete_resumes_buy_prompt_from_snapshot_pending_action() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 4)
    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 3,
            "current_player_index": 1,
            "current_cycle": 1,
            "pending_action": {
                "type": "buy_or_end_turn",
                "tile_index": 6,
            },
            "board_state": {
                "size": 18,
                "tiles": [
                    {
                        "index": 6,
                        "city": "Patagonia",
                    },
                ],
            },
            "has_started": true,
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.turn_prompt_count, 0, "buy pending action does not prompt roll")
    assert_eq(client.buy_prompt_count, 1, "buy pending action prompts buy or end turn")
    assert_eq(client.pay_toll_prompt_count, 0, "buy pending action does not prompt pay toll")
    client.free()


func test_sync_complete_resumes_pay_toll_prompt_from_snapshot_pending_action() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 4)
    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 3,
            "current_player_index": 1,
            "current_cycle": 1,
            "pending_action": {
                "type": "pay_toll",
                "tile_index": 13,
                "owner_index": 0,
                "amount": 0.6,
            },
            "board_state": {
                "size": 18,
                "tiles": [
                    {
                        "index": 13,
                        "city": "El Salvador",
                    },
                ],
            },
            "has_started": true,
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.turn_prompt_count, 0, "pay toll pending action does not prompt roll")
    assert_eq(client.buy_prompt_count, 0, "pay toll pending action does not prompt buy")
    assert_eq(client.pay_toll_prompt_count, 1, "pay toll pending action prompts pay toll")
    assert_eq(client.server_calls.size(), 2, "sync request and pay toll RPC emitted")
    assert_eq(str(client.server_calls[1].get("method", "")), "rpc_pay_toll", "pay toll path sends pay_toll rpc")
    client.free()


func test_sync_complete_does_not_resume_pay_toll_for_other_player() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 4)
    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 3,
            "current_player_index": 0,
            "current_cycle": 1,
            "pending_action": {
                "type": "pay_toll",
                "tile_index": 13,
                "owner_index": 1,
                "amount": 0.75,
            },
            "board_state": {
                "size": 18,
                "tiles": [
                    {
                        "index": 13,
                        "city": "El Salvador",
                    },
                ],
            },
            "has_started": true,
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.turn_prompt_count, 0, "no roll prompt for other player's pending action")
    assert_eq(client.buy_prompt_count, 0, "no buy prompt for other player's pending action")
    assert_eq(client.pay_toll_prompt_count, 0, "no pay toll prompt for other player's pending action")
    assert_eq(client.server_calls.size(), 1, "only sync request rpc emitted")
    client.free()


func test_sync_complete_logs_turn_summary_for_non_current_player() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 4)
    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 1,
            "current_player_index": 0,
            "current_cycle": 1,
            "pending_action": { },
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "has_started": true,
            "players": [
                {
                    "player_index": 0,
                    "player_id": "p0",
                    "joined": true,
                    "ready": false,
                    "position": 0,
                    "laps": 0,
                    "fiat_balance": 120.0,
                    "bitcoin_balance": 0.0,
                    "in_inspection": false,
                    "inspection_free_exits": 0,
                },
                {
                    "player_index": 1,
                    "player_id": "p1",
                    "joined": true,
                    "ready": false,
                    "position": 0,
                    "laps": 0,
                    "fiat_balance": 120.0,
                    "bitcoin_balance": 0.0,
                    "in_inspection": false,
                    "inspection_free_exits": 0,
                },
            ],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.turn_prompt_count, 0, "non-current player should not be prompted to roll")
    assert_true(client.server_messages.has("\u001b[32mgame resumed\u001b[0m: game_id=demo_002"), "sync resume logs game resumed label")
    assert_true(client.server_messages.has("sync resume: waiting for current player=0 turn=1"), "sync resume explains no prompt because it is another player's turn")
    var expected_turn_log: String = "\u001b[32mturn started\u001b[0m: player=0, turn=1, cycle=1, connected_players=[p0(tile=0 fiat=\u001b[1m\u001b[33m120.00\u001b[0m btc=\u001b[33m0.00000000\u001b[0m properties=0), p1(tile=0 fiat=\u001b[1m\u001b[33m120.00\u001b[0m btc=\u001b[33m0.00000000\u001b[0m properties=0)]"
    assert_true(client.server_messages.has(expected_turn_log), "sync resume logs turn started summary for observing player")
    client.free()


func test_sync_complete_does_not_prompt_roll_when_match_not_started() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 4)
    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 1,
            "current_player_index": 1,
            "current_cycle": 1,
            "pending_action": { },
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "has_started": false,
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.turn_prompt_count, 0, "match not started should not prompt roll")
    assert_eq(client.buy_prompt_count, 0, "match not started should not prompt buy")
    assert_eq(client.pay_toll_prompt_count, 0, "match not started should not prompt pay toll")
    client.free()


func test_sync_complete_does_not_prompt_when_match_is_finished() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_id = "p2"
    client.game_id = "demo_002"

    client._handle_join_accepted(0, "p2", 1, 4)
    client._handle_state_snapshot(
        0,
        {
            "game_id": "demo_002",
            "turn_number": 7,
            "current_player_index": 1,
            "current_cycle": 3,
            "pending_action": { },
            "board_state": {
                "size": 18,
                "tiles": [],
            },
            "has_started": true,
            "has_finished": true,
            "winner_index": 0,
            "end_reason": "btc_goal_reached",
            "players": [],
        },
    )
    client._handle_sync_complete(0, 4)

    assert_eq(client.turn_prompt_count, 0, "finished match should not prompt roll")
    assert_eq(client.buy_prompt_count, 0, "finished match should not prompt buy")
    assert_eq(client.pay_toll_prompt_count, 0, "finished match should not prompt pay toll")
    client.free()


func test_action_rejected_insufficient_fiat_on_buy_auto_sends_end_turn() -> void:
    var client: ClientMainDouble = ClientMainDouble.new()
    client.player_index = 0
    client.current_player_index = 0
    client.pending_action_type = "buy_or_end_turn"
    client.game_id = "demo_002"
    client.player_id = "alice"

    client._apply_action_rejected("insufficient_fiat")

    assert_eq(client.server_calls.size(), 1, "insufficient fiat rejection should trigger one fallback rpc")
    assert_eq(str(client.server_calls[0].get("method", "")), "rpc_end_turn", "fallback should send end_turn")
    var args: Array = client.server_calls[0].get("args", [])
    assert_eq(str(args[0]), "demo_002", "fallback end_turn includes game id")
    assert_eq(str(args[1]), "alice", "fallback end_turn includes player id")
    client.free()
