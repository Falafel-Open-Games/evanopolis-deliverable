class_name PlayersListPanel
extends MarginContainer

const COLLAPSED_SIZE: Vector2 = Vector2(0, 0)
const EXPANDED_SIZE: Vector2 = Vector2(210, 265)
const PlayerListCardScene = preload("res://scenes/game/hud/player_list_card.tscn")

@onready var toggle_button: Button = get_node(^"MarginContainer/ListToggleButton")
@onready var player_list_seats: VBoxContainer = get_node(^"MarginContainer2/PlayerListSeats")

var _player_slots: Array = []

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

func _on_toggle_button_pressed() -> void:
    if is_equal_approx(custom_minimum_size.x, EXPANDED_SIZE.x):
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
        player_list_seats.add_child(seat_card)
        seat_card.call("set_player_state", slot_variant)
