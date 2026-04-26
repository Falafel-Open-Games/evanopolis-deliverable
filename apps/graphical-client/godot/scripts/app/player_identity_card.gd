class_name PlayerIdentityCard
extends HBoxContainer

const HANDLE_COLOR: Color = Color(0.823529, 0.831373, 0.756863, 1.0)
const NAME_COLOR: Color = Color(0.980392, 0.94902, 0.870588, 1.0)
const PLAYER_REPRESENTATION_COLORS: Array[Color] = [
    Color(0.0, 0.784314, 0.32549, 1.0),
    Color(0.0, 0.690196, 1.0, 1.0),
    Color(1.0, 0.839216, 0.0, 1.0),
    Color(1.0, 0.419608, 0.207843, 1.0),
    Color(0.898039, 0.223529, 0.207843, 1.0),
    Color(0.556863, 0.141176, 0.666667, 1.0),
]
const DEFAULT_ICON_FRAME: int = 11
const DEFAULT_COLOR_SLOT: int = 1

@export var hexagon_texture: TextureRect
@export var icon_sprite: Sprite2D
@export var display_name_label: Label
@export var handle_label: Label

var _identity_initialized: bool = false

func _ready() -> void:
    assert(hexagon_texture)
    assert(icon_sprite)
    assert(display_name_label)
    assert(handle_label)

    if not _identity_initialized:
        set_identity("Player", "No player id yet", DEFAULT_ICON_FRAME, DEFAULT_COLOR_SLOT)

func set_identity(display_name: String, handle_text: String, icon_frame: int = DEFAULT_ICON_FRAME, color_slot: int = DEFAULT_COLOR_SLOT) -> void:
    _identity_initialized = true
    var resolved_display_name: String = display_name.strip_edges()
    var resolved_handle: String = handle_text.strip_edges()
    if resolved_display_name.is_empty():
        resolved_display_name = resolved_handle if not resolved_handle.is_empty() else "Player"
    if resolved_handle.is_empty():
        resolved_handle = "No player id yet"

    display_name_label.text = resolved_display_name
    handle_label.text = resolved_handle

    display_name_label.add_theme_color_override("font_color", NAME_COLOR)
    handle_label.add_theme_color_override("font_color", HANDLE_COLOR)

    icon_sprite.frame = icon_frame
    hexagon_texture.modulate = _color_from_slot(color_slot)

func _color_from_slot(color_slot: int) -> Color:
    if color_slot < 1 or color_slot > PLAYER_REPRESENTATION_COLORS.size():
        return PLAYER_REPRESENTATION_COLORS[0]
    return PLAYER_REPRESENTATION_COLORS[color_slot - 1]
