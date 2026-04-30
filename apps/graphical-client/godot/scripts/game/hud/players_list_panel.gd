class_name PlayersListPanel
extends MarginContainer

const COLLAPSED_SIZE: Vector2 = Vector2(0, 0)
const EXPANDED_SIZE: Vector2 = Vector2(210, 265)

@onready var toggle_button: Button = get_node(^"MarginContainer/ListToggleButton")

func _ready() -> void:
    assert(toggle_button)
    toggle_button.pressed.connect(_on_toggle_button_pressed)
    _sync_collapsed_state()

func _on_toggle_button_pressed() -> void:
    if is_equal_approx(custom_minimum_size.x, EXPANDED_SIZE.x):
        custom_minimum_size = COLLAPSED_SIZE
    else:
        custom_minimum_size = EXPANDED_SIZE

func _sync_collapsed_state() -> void:
    if custom_minimum_size.x <= 0.0:
        custom_minimum_size = COLLAPSED_SIZE
