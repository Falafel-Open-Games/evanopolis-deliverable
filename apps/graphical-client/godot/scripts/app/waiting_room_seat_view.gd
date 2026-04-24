extends Control

const WaitingRoomSlot = preload("res://scripts/app/models/waiting_room_slot.gd")

const ACCENT_COLOR: Color = Color(0.913725, 0.682353, 0.337255, 1.0)
const PRIMARY_TEXT_COLOR: Color = Color(0.980392, 0.94902, 0.870588, 1.0)
const SECONDARY_TEXT_COLOR: Color = Color(0.823529, 0.831373, 0.756863, 1.0)
const READY_COLOR: Color = Color(0.403922, 0.784314, 0.423529, 1.0)
const PANEL_COLOR: Color = Color(0.0549019, 0.0862745, 0.0901961, 0.84)
const LOCAL_SEAT_COLOR: Color = Color(0.0862745, 0.160784, 0.145098, 0.92)
const OPEN_SEAT_COLOR: Color = Color(0.0980392, 0.113725, 0.117647, 0.9)

@export var background_rect: ColorRect
@export var slot_index_label: Label
@export var name_label: Label
@export var status_label: Label
@export var badge_label: Label

func _ready() -> void:
    assert(background_rect)
    assert(slot_index_label)
    assert(name_label)
    assert(status_label)
    assert(badge_label)

func set_slot(slot: WaitingRoomSlot) -> void:
    background_rect.color = _seat_background_color(slot)
    slot_index_label.text = str(slot.player_index + 1)
    name_label.text = slot.display_name
    status_label.text = slot.status_text

    slot_index_label.add_theme_color_override("font_color", ACCENT_COLOR)
    name_label.add_theme_color_override("font_color", PRIMARY_TEXT_COLOR)
    status_label.add_theme_color_override(
        "font_color",
        READY_COLOR if slot.is_ready else SECONDARY_TEXT_COLOR
    )

    if slot.is_ready:
        badge_label.add_theme_color_override("font_color", READY_COLOR)
        badge_label.text = "READY"
    elif slot.is_known_player:
        badge_label.add_theme_color_override("font_color", ACCENT_COLOR)
        badge_label.text = "JOINED"
    else:
        badge_label.add_theme_color_override("font_color", SECONDARY_TEXT_COLOR)
        badge_label.text = "OPEN"

func _seat_background_color(slot: WaitingRoomSlot) -> Color:
    if slot.is_local:
        return LOCAL_SEAT_COLOR
    if slot.is_known_player:
        return PANEL_COLOR
    return OPEN_SEAT_COLOR
