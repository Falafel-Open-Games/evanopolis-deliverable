class_name PlayersListPanel
extends MarginContainer

const COLLAPSED_SIZE: Vector2 = Vector2(0, 0)
const EXPANDED_SIZE: Vector2 = Vector2(210, 0)
const PlayerListCardScene = preload("res://scenes/game/hud/player_list_card.tscn")

@onready var toggle_button: Button = get_node(^"VBoxContainer/MarginContainer/ListToggleButton")
@onready var player_list_seats: VBoxContainer = get_node(^"VBoxContainer/PlayerListSeats/VBoxContainer")

var _player_slots: Array = []
var _current_turn_player_index: int = -1

func _ready() -> void:
    assert(toggle_button)
    assert(player_list_seats)
    toggle_button.pressed.connect(_on_toggle_button_pressed)
    _sync_collapsed_state()
    _rebuild_seats()

func set_player_states(player_states: Array) -> void:
    _player_slots = player_states.duplicate()
    if not is_node_ready():
        return
    _rebuild_seats()

func set_current_turn_player_index(player_index: int) -> void:
    _current_turn_player_index = player_index
    if not is_node_ready():
        return
    _sync_turn_highlight()

func _on_toggle_button_pressed() -> void:
    if player_list_seats.visible == true:
        custom_minimum_size = COLLAPSED_SIZE
        player_list_seats.visible = false
    else:
        custom_minimum_size = EXPANDED_SIZE
        player_list_seats.visible = true

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

    for slot_variant in _player_slots:
        var seat_card: Control = PlayerListCardScene.instantiate()
        assert(seat_card.has_method("set_player_state"))
        assert(seat_card.has_method("set_is_current_turn_player"))
        player_list_seats.add_child(seat_card)
        seat_card.call("set_player_state", slot_variant)
        seat_card.call("set_is_current_turn_player", int(slot_variant.player_index) == _current_turn_player_index)

func _sync_turn_highlight() -> void:
    var seat_cards: Array = player_list_seats.get_children()
    for seat_index in range(seat_cards.size()):
        var seat_card: Node = seat_cards[seat_index]
        if not seat_card.has_method("set_is_current_turn_player"):
            continue
        if seat_index >= _player_slots.size():
            continue
        var player_index: int = int(_player_slots[seat_index].player_index)
        seat_card.call("set_is_current_turn_player", player_index == _current_turn_player_index)
