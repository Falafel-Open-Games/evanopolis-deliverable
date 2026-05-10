class_name TopBar
extends Panel

const AvatarBoxControl = preload("res://scripts/app/avatar_box.gd")
const GameEconomyConfigModel = preload("res://scripts/app/models/game_economy_config.gd")
const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")
const LOCAL_TURN_COLOR: Color = Color(0.015686275, 0.8, 0.68235296, 1.0)
const OTHER_TURN_COLOR: Color = Color(0.980392, 0.94902, 0.870588, 1.0)

signal energy_allocation_toggle_requested(is_pressed: bool)

@export var avatar_box: AvatarBoxControl
@onready var turn_label: Label = get_node(^"MarginContainer/HBoxContainer/VBoxContainer/TurnLabel")
@onready var bitcoin_value_label: Label = get_node(^"MarginContainer/GameResources/MarginContainer2/HBoxContainer/MarginContainer3/VBoxContainer2/BitcoinValue")
@onready var bitcoin_progress_bar: ProgressBar = get_node(^"MarginContainer/GameResources/MarginContainer2/HBoxContainer/MarginContainer3/VBoxContainer2/ProgressBar")
@onready var fiat_value_label: Label = get_node(^"MarginContainer/GameResources/MarginContainer2/HBoxContainer/MarginContainer/VBoxContainer/FiatValue")
@onready var fiat_value_per_turn_label: Label = get_node(^"MarginContainer/PerTurnSummary/HBoxContainer/VBoxContainer/HBoxContainer2/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/FiatValuePerTurn")
@onready var bitcoin_value_per_turn_label: Label = get_node(^"MarginContainer/PerTurnSummary/HBoxContainer/VBoxContainer/HBoxContainer2/MarginContainer/HBoxContainer/MarginContainer3/VBoxContainer2/BitcoinValuePerTurn")
@export var energy_value_label: Label
@onready var open_allocation_button: Button = get_node(^"MarginContainer/PerTurnSummary/HBoxContainer/OpenAllocationButton")

func _ready() -> void:
    assert(avatar_box)
    assert(turn_label)
    assert(bitcoin_value_label)
    assert(bitcoin_progress_bar)
    assert(fiat_value_label)
    assert(fiat_value_per_turn_label)
    assert(bitcoin_value_per_turn_label)
    assert(energy_value_label)
    assert(open_allocation_button)
    bitcoin_value_label.text = "₿ %.1f/%.0f" % [
        GameEconomyConfigModel.INITIAL_BITCOIN_BALANCE,
        GameEconomyConfigModel.BITCOIN_GOAL_TO_WIN,
    ]
    bitcoin_progress_bar.max_value = GameEconomyConfigModel.BITCOIN_GOAL_TO_WIN
    fiat_value_label.text = "$ %.2f" % GameEconomyConfigModel.INITIAL_FIAT_BALANCE
    energy_value_label.text = "⚡ %d" % GameEconomyConfigModel.INITIAL_ENERGY_BALANCE
    set_per_turn_production(50, 0.0, 0.0)
    open_allocation_button.toggled.connect(_on_open_allocation_button_toggled)
    set_energy_allocation_toggle_state(false, false)

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    avatar_box.set_icon_id(icon_id)
    avatar_box.set_hexagon_modulate(_color_from_id(color_id))

func set_local_player_resources(fiat_balance: float, energy_amount: int, bitcoin_balance: float) -> void:
    fiat_value_label.text = "$ %.2f" % fiat_balance
    energy_value_label.text = "⚡ %d" % energy_amount
    bitcoin_value_label.text = "₿ %.1f/%.0f" % [
        bitcoin_balance,
        GameEconomyConfigModel.BITCOIN_GOAL_TO_WIN,
    ]
    bitcoin_progress_bar.value = bitcoin_balance

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

func set_energy_allocation_toggle_state(is_available: bool, is_pressed: bool) -> void:
    open_allocation_button.visible = is_available
    open_allocation_button.set_pressed_no_signal(is_available and is_pressed)

func set_per_turn_production(sell_percent: int, sell_100_fiat_total: float, mine_100_btc_total: float) -> void:
    var normalized_sell_percent: int = clampi(sell_percent, 0, 100)
    var mine_percent: int = 100 - normalized_sell_percent
    var fiat_per_turn: float = maxf(0.0, sell_100_fiat_total) * (float(normalized_sell_percent) / 100.0)
    var bitcoin_per_turn: float = maxf(0.0, mine_100_btc_total) * (float(mine_percent) / 100.0)
    fiat_value_per_turn_label.text = "$ %s" % _format_amount(fiat_per_turn, 2)
    bitcoin_value_per_turn_label.text = "₿ %s" % _format_amount(bitcoin_per_turn, 4)

func _on_open_allocation_button_toggled(is_pressed: bool) -> void:
    energy_allocation_toggle_requested.emit(is_pressed)

func _format_amount(value: float, decimals: int) -> String:
    var text: String = String.num(value, decimals)
    while text.contains(".") and (text.ends_with("0") or text.ends_with(".")):
        if text.ends_with("."):
            text = text.substr(0, text.length() - 1)
            break
        text = text.substr(0, text.length() - 1)
    return text

func _color_from_id(color_id: int) -> Color:
    if color_id < 0 or color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size():
        return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[PlayerIdentityCardView.DEFAULT_COLOR_ID]
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[color_id]
