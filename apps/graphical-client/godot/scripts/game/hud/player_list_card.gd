class_name PlayerListCard
extends MarginContainer

const GamePlayerHudState = preload("res://scripts/app/models/game_player_hud_state.gd")
const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")

const BITCOIN_GOAL: float = 20.0

@onready var slot_index_label: Label = get_node(^"SlotIndex")
@onready var avatar_box: AvatarBox = get_node(^"SeatRow/AvatarBox")
@onready var display_name_label: Label = get_node(^"SeatRow/VBoxContainer/DisplayNameLabel")
@onready var fiat_value_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/FiatValue")
@onready var energy_value_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/EnergyValue")
@onready var bitcoin_value_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/BitcoinValue")

func _ready() -> void:
    assert(slot_index_label)
    assert(avatar_box)
    assert(display_name_label)
    assert(fiat_value_label)
    assert(energy_value_label)
    assert(bitcoin_value_label)

func set_player_state(player_state: GamePlayerHudState) -> void:
    slot_index_label.text = str(player_state.player_index + 1)
    avatar_box.set_icon_id(player_state.icon_id)
    avatar_box.set_hexagon_modulate(_color_from_id(player_state.color_id))
    display_name_label.text = _resolved_display_name(player_state)
    display_name_label.remove_theme_color_override("font_color")
    fiat_value_label.text = "$ %.2f" % player_state.fiat_balance
    energy_value_label.text = "⚡ %d" % player_state.energy_amount
    bitcoin_value_label.text = "₿ %.1f/%.0f" % [player_state.bitcoin_balance, BITCOIN_GOAL]

func _resolved_display_name(player_state: GamePlayerHudState) -> String:
    var display_name: String = player_state.display_name.strip_edges()
    if not display_name.is_empty():
        return display_name
    if player_state.is_local:
        return "You"
    return "Player %d" % (player_state.player_index + 1)

func _color_from_id(color_id: int) -> Color:
    if color_id < 0 or color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size():
        return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[PlayerIdentityCardView.DEFAULT_COLOR_ID]
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[color_id]
