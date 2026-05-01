extends RefCounted

var player_index: int
var display_name: String
var is_local: bool
var icon_id: int
var color_id: int
var fiat_balance: float
var energy_amount: int
var bitcoin_balance: float

func _init(
    initial_player_index: int,
    initial_display_name: String,
    initial_is_local: bool,
    initial_icon_id: int,
    initial_color_id: int,
    initial_fiat_balance: float,
    initial_energy_amount: int,
    initial_bitcoin_balance: float
) -> void:
    player_index = initial_player_index
    display_name = initial_display_name
    is_local = initial_is_local
    icon_id = initial_icon_id
    color_id = initial_color_id
    fiat_balance = initial_fiat_balance
    energy_amount = initial_energy_amount
    bitcoin_balance = initial_bitcoin_balance

func clone():
    return get_script().new(
        player_index,
        display_name,
        is_local,
        icon_id,
        color_id,
        fiat_balance,
        energy_amount,
        bitcoin_balance
    )
