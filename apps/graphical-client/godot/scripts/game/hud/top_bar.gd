class_name TopBar
extends Panel

const AvatarBoxControl = preload("res://scripts/app/avatar_box.gd")
const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")

@export var avatar_box: AvatarBoxControl

func _ready() -> void:
    assert(avatar_box)

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    avatar_box.set_icon_id(icon_id)
    avatar_box.set_hexagon_modulate(_color_from_id(color_id))

func _color_from_id(color_id: int) -> Color:
    if color_id < 0 or color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size():
        return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[PlayerIdentityCardView.DEFAULT_COLOR_ID]
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[color_id]
