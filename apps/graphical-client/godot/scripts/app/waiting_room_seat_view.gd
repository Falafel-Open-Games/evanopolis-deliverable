extends Control

const WaitingRoomSlot = preload("res://scripts/app/models/waiting_room_slot.gd")
const PlayerIdentityCard = preload("res://scripts/app/player_identity_card.gd")

const ACCENT_COLOR: Color = Color(0.913725, 0.682353, 0.337255, 1.0)
const SECONDARY_TEXT_COLOR: Color = Color(0.823529, 0.831373, 0.756863, 1.0)
const READY_COLOR: Color = Color(0.403922, 0.784314, 0.423529, 1.0)
const PANEL_COLOR: Color = Color(0.0549019, 0.0862745, 0.0901961, 0.84)
const LOCAL_SEAT_COLOR: Color = Color(0.0862745, 0.160784, 0.145098, 0.92)
const OPEN_SEAT_COLOR: Color = Color(0.0980392, 0.113725, 0.117647, 0.9)
const DEFAULT_IDENTITY_ICON_FRAME: int = 11
const DEFAULT_IDENTITY_COLOR_SLOT: int = 1

@export var background_rect: ColorRect
@export var slot_index_label: Label
@export var identity_card: PlayerIdentityCard
@export var badge_label: Label

func _ready() -> void:
    assert(background_rect)
    assert(slot_index_label)
    assert(identity_card)
    assert(badge_label)

func set_slot(slot: WaitingRoomSlot) -> void:
    background_rect.color = _seat_background_color(slot)
    slot_index_label.text = str(slot.player_index + 1)
    identity_card.set_identity(
        slot.display_name,
        slot.player_id,
        DEFAULT_IDENTITY_ICON_FRAME,
        DEFAULT_IDENTITY_COLOR_SLOT
    )

    slot_index_label.add_theme_color_override("font_color", ACCENT_COLOR)

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
