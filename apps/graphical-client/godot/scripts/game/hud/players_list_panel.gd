class_name PlayersListPanel
extends MarginContainer

const COLLAPSED_SIZE: Vector2 = Vector2(0, 0)
#const EXPANDED_SIZE: Vector2 = Vector2(50, 0)
const PlayerListCardScene = preload("res://scenes/game/hud/player_list_card.tscn")

@onready var toggle_button: Button = get_node(^"VBoxContainer/MarginContainer/ListToggleButton")
@onready var player_list_seats: VBoxContainer = get_node(^"VBoxContainer/PlayerListSeats/VBoxContainer")

var _player_states: Array = []
var _current_turn_player_index: int = -1
var _is_match_finished: bool = false

func _ready() -> void:
    assert(toggle_button)
    assert(player_list_seats)
    toggle_button.pressed.connect(_on_toggle_button_pressed)
    _sync_collapsed_state()
    _rebuild_seats()

func set_player_states(player_states: Array) -> void:
    _player_states = player_states.duplicate()
    if not is_node_ready():
        return
    _rebuild_seats()

func set_current_turn_player_index(player_index: int) -> void:
    _current_turn_player_index = player_index
    if not is_node_ready():
        return
    _sync_turn_highlight()

func set_match_finished(is_match_finished: bool) -> void:
    _is_match_finished = is_match_finished
    if not is_node_ready():
        return
    _rebuild_seats()

func _on_toggle_button_pressed() -> void:
    if player_list_seats.visible == true:
        custom_minimum_size = COLLAPSED_SIZE
        player_list_seats.visible = false
        size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    else:
        #custom_minimum_size = EXPANDED_SIZE
        player_list_seats.visible = true
        #size_flags_vertical = Control.SIZE_EXPAND_FILL


func _sync_collapsed_state() -> void:
    if custom_minimum_size.x <= 0.0:
        custom_minimum_size = COLLAPSED_SIZE
        player_list_seats.visible = false
        return
    player_list_seats.visible = true

func _rebuild_seats() -> void:
    for child in player_list_seats.get_children():
        player_list_seats.remove_child(child)
        child.queue_free()

    for player_state_variant in _player_states:
        var seat_card: Control = PlayerListCardScene.instantiate()
        assert(seat_card.has_method("set_player_state"))
        assert(seat_card.has_method("set_is_current_turn_player"))
        assert(seat_card.has_method("set_resource_leader_markers"))
        player_list_seats.add_child(seat_card)
        seat_card.call("set_player_state", player_state_variant)
        seat_card.call("set_is_current_turn_player", int(player_state_variant.player_index) == _current_turn_player_index)
        seat_card.call(
            "set_resource_leader_markers",
            _is_match_finished and _is_fiat_leader(player_state_variant),
            _is_match_finished and _is_energy_leader(player_state_variant),
            _is_match_finished and _is_bitcoin_leader(player_state_variant)
        )

func _sync_turn_highlight() -> void:
    var seat_cards: Array = player_list_seats.get_children()
    for seat_index in range(seat_cards.size()):
        var seat_card: Node = seat_cards[seat_index]
        if not seat_card.has_method("set_is_current_turn_player"):
            continue
        if seat_index >= _player_states.size():
            continue
        var player_index: int = int(_player_states[seat_index].player_index)
        seat_card.call("set_is_current_turn_player", player_index == _current_turn_player_index)

func _is_fiat_leader(player_state_variant: Variant) -> bool:
    var player_fiat_balance: float = float(player_state_variant.fiat_balance)
    return is_equal_approx(player_fiat_balance, _highest_fiat_balance())

func _is_energy_leader(player_state_variant: Variant) -> bool:
    return int(player_state_variant.energy_amount) == _highest_energy_amount()

func _is_bitcoin_leader(player_state_variant: Variant) -> bool:
    var player_bitcoin_balance: float = float(player_state_variant.bitcoin_balance)
    return is_equal_approx(player_bitcoin_balance, _highest_bitcoin_balance())

func _highest_fiat_balance() -> float:
    var highest_fiat_balance: float = 0.0
    for player_state_variant in _player_states:
        highest_fiat_balance = maxf(highest_fiat_balance, float(player_state_variant.fiat_balance))
    return highest_fiat_balance

func _highest_energy_amount() -> int:
    var highest_energy_amount: int = 0
    for player_state_variant in _player_states:
        highest_energy_amount = maxi(highest_energy_amount, int(player_state_variant.energy_amount))
    return highest_energy_amount

func _highest_bitcoin_balance() -> float:
    var highest_bitcoin_balance: float = 0.0
    for player_state_variant in _player_states:
        highest_bitcoin_balance = maxf(highest_bitcoin_balance, float(player_state_variant.bitcoin_balance))
    return highest_bitcoin_balance
