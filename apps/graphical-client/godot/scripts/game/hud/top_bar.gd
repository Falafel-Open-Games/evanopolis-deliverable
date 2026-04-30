class_name TopBar
extends Panel

const AvatarBoxControl = preload("res://scripts/app/avatar_box.gd")
const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")

@export var avatar_box: AvatarBoxControl
@onready var turn_label: Label = get_node(^"MarginContainer/HBoxContainer/VBoxContainer/TurnLabel")

func _ready() -> void:
    assert(avatar_box)
    assert(turn_label)

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    avatar_box.set_icon_id(icon_id)
    avatar_box.set_hexagon_modulate(_color_from_id(color_id))

func set_turn_info(turn_number: int, player_name: String, is_local_turn: bool) -> void:
    var resolved_turn_number: int = max(1, turn_number)
    if is_local_turn:
        turn_label.text = "Turn %d - Your turn" % resolved_turn_number
        return

    var resolved_player_name: String = player_name.strip_edges()
    if resolved_player_name.is_empty():
        resolved_player_name = "Player"
    turn_label.text = "Turn %d - %s" % [resolved_turn_number, resolved_player_name]

func _color_from_id(color_id: int) -> Color:
    if color_id < 0 or color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size():
        return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[PlayerIdentityCardView.DEFAULT_COLOR_ID]
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[color_id]
