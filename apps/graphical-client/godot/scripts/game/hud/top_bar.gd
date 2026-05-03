class_name TopBar
extends Panel

const AvatarBoxControl = preload("res://scripts/app/avatar_box.gd")
const GameEconomyConfigModel = preload("res://scripts/app/models/game_economy_config.gd")
const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")
const LOCAL_TURN_COLOR: Color = Color(0.015686275, 0.8, 0.68235296, 1.0)
const OTHER_TURN_COLOR: Color = Color(0.980392, 0.94902, 0.870588, 1.0)

@export var avatar_box: AvatarBoxControl
@onready var turn_label: Label = get_node(^"MarginContainer/HBoxContainer/VBoxContainer/TurnLabel")
@onready var game_goal_value_label: Label = get_node(^"MarginContainer/HBoxContainer/GameGoal/MarginContainer/VBoxContainer/HBoxContainer/Label")
@onready var game_goal_progress_bar: ProgressBar = get_node(^"MarginContainer/HBoxContainer/GameGoal/MarginContainer/ProgressBar")
@onready var fiat_value_label: Label = get_node(^"MarginContainer/GameResources/MarginContainer2/HBoxContainer/MarginContainer/VBoxContainer/FiatValue")
@onready var energy_value_label: Label = get_node(^"MarginContainer/GameResources/MarginContainer2/HBoxContainer/MarginContainer2/VBoxContainer2/EnergyValue")

func _ready() -> void:
    assert(avatar_box)
    assert(turn_label)
    assert(game_goal_value_label)
    assert(game_goal_progress_bar)
    assert(fiat_value_label)
    assert(energy_value_label)
    game_goal_value_label.text = "₿ %.1f/%.0f" % [
        GameEconomyConfigModel.INITIAL_BITCOIN_BALANCE,
        GameEconomyConfigModel.BITCOIN_GOAL_TO_WIN,
    ]
    game_goal_progress_bar.max_value = GameEconomyConfigModel.BITCOIN_GOAL_TO_WIN
    fiat_value_label.text = "$ %.2f" % GameEconomyConfigModel.INITIAL_FIAT_BALANCE
    energy_value_label.text = "⚡ %d" % GameEconomyConfigModel.INITIAL_ENERGY_BALANCE

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    avatar_box.set_icon_id(icon_id)
    avatar_box.set_hexagon_modulate(_color_from_id(color_id))

func set_turn_info(turn_number: int, player_name: String, is_local_turn: bool) -> void:
    var resolved_turn_number: int = max(1, turn_number)
    if is_local_turn:
        turn_label.add_theme_color_override("font_color", LOCAL_TURN_COLOR)
        turn_label.text = "Turn %d - Your turn" % resolved_turn_number
        return

    var resolved_player_name: String = player_name.strip_edges()
    if resolved_player_name.is_empty():
        resolved_player_name = "Player"
    turn_label.add_theme_color_override("font_color", OTHER_TURN_COLOR)
    turn_label.text = "Turn %d - %s" % [resolved_turn_number, resolved_player_name]

func _color_from_id(color_id: int) -> Color:
    if color_id < 0 or color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size():
        return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[PlayerIdentityCardView.DEFAULT_COLOR_ID]
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[color_id]
