extends Node

@rpc("any_peer")
func rpc_join(_game_id: String, _player_id: String) -> void:
    pass

@rpc("any_peer")
func rpc_auth(_token: String) -> void:
    pass

@rpc("any_peer")
func rpc_roll_dice(_game_id: String, _player_id: String) -> void:
    pass

@rpc("any_peer")
func rpc_end_turn(_game_id: String, _player_id: String) -> void:
    pass

@rpc("any_peer")
func rpc_buy_property(_game_id: String, _player_id: String, _tile_index: int) -> void:
    pass

@rpc("any_peer")
func rpc_pay_toll(_game_id: String, _player_id: String) -> void:
    pass

@rpc("any_peer")
func rpc_sync_request(_game_id: String, _player_id: String, _last_applied_seq: int) -> void:
    pass

@rpc("any_peer")
func rpc_player_ready(_game_id: String, _player_id: String) -> void:
    pass

@rpc("any_peer")
func rpc_set_player_identity(_game_id: String, _player_id: String, _display_name: String, _icon_id: int, _color_id: int) -> void:
    pass

@rpc("authority")
func rpc_game_started(_seq: int, _new_game_id: String) -> void:
    pass

@rpc("authority")
func rpc_board_state(_seq: int, _board: Dictionary) -> void:
    pass

@rpc("authority")
func rpc_auth_ok(_player_id: String, _auth_exp: int) -> void:
    pass

@rpc("authority")
func rpc_auth_error(_reason: String) -> void:
    pass

@rpc("authority")
func rpc_join_accepted(_seq: int, _player_id: String, _player_index: int, _last_seq: int) -> void:
    pass

@rpc("authority")
func rpc_turn_started(_seq: int, _player_index: int, _turn_number: int, _cycle: int) -> void:
    pass

@rpc("authority")
func rpc_game_ended(_seq: int, _winner_index: int, _reason: String, _btc_goal: float, _winner_btc: float) -> void:
    pass

@rpc("authority")
func rpc_player_ready_state(_seq: int, _player_index: int, _is_ready: bool, _ready_count: int, _total_players: int) -> void:
    pass

@rpc("authority")
func rpc_player_joined(_seq: int, _player_id: String, _player_index: int) -> void:
    pass

@rpc("authority")
func rpc_player_identity_changed(_seq: int, _player_index: int, _display_name: String, _icon_id: int, _color_id: int) -> void:
    pass

@rpc("authority")
func rpc_dice_rolled(_seq: int, _die_1: int, _die_2: int, _total: int) -> void:
    pass

@rpc("authority")
func rpc_pawn_moved(_seq: int, _from_tile: int, _to_tile: int, _passed_tiles: Array[int]) -> void:
    pass

@rpc("authority")
func rpc_tile_landed(
        _seq: int,
        _tile_index: int,
        _tile_type: String,
        _city: String,
        _owner_index: int,
        _toll_due: float,
        _buy_price: float,
        _energy_production: int,
        _sell_100_fiat: float,
        _mine_100_btc: float,
        _action_required: String,
) -> void:
    pass

@rpc("authority")
func rpc_player_balance_changed(_seq: int, _player_index: int, _fiat_delta: float, _btc_delta: float, _reason: String) -> void:
    pass

@rpc("authority")
func rpc_cycle_started(_seq: int, _cycle: int) -> void:
    pass

@rpc("authority")
func rpc_property_acquired(_seq: int, _player_index: int, _tile_index: int, _price: float) -> void:
    pass

@rpc("authority")
func rpc_toll_paid(_seq: int, _payer_index: int, _owner_index: int, _amount: float) -> void:
    pass

@rpc("authority")
func rpc_state_snapshot(_seq: int, _snapshot: Dictionary) -> void:
    pass

@rpc("authority")
func rpc_sync_complete(_seq: int, _final_seq: int) -> void:
    pass

@rpc("authority")
func rpc_action_rejected(_seq: int, _reason: String) -> void:
    pass
