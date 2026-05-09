class_name PlayerListCard
extends MarginContainer

const GamePlayerHudState = preload("res://scripts/app/models/game_player_hud_state.gd")
const GameEconomyConfigModel = preload("res://scripts/app/models/game_economy_config.gd")
const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")

@onready var background_highlight: Panel = get_node(^"BackgroundHighlight")
@onready var avatar_box: AvatarBox = get_node(^"SeatRow/AvatarBox")
@onready var display_name_label: Label = get_node(^"SeatRow/VBoxContainer/DisplayNameLabel")
@onready var fiat_icon_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/FiatIcon")
@onready var fiat_value_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/FiatValue")
@onready var energy_icon_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/EnergyIcon")
@onready var energy_value_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/EnergyValue")
@onready var bitcoin_icon_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/BitcoinIcon")
@onready var bitcoin_value_label: Label = get_node(^"SeatRow/VBoxContainer/HBoxContainer/BitcoinValue")

var _fiat_balance: float = 0.0
var _energy_amount: int = 0
var _bitcoin_balance: float = 0.0
var _is_fiat_leader: bool = false
var _is_energy_leader: bool = false
var _is_bitcoin_leader: bool = false

func _ready() -> void:
    assert(background_highlight)
    assert(avatar_box)
    assert(display_name_label)
    assert(fiat_icon_label)
    assert(fiat_value_label)
    assert(energy_icon_label)
    assert(energy_value_label)
    assert(bitcoin_icon_label)
    assert(bitcoin_value_label)

func set_player_state(player_state: GamePlayerHudState) -> void:
    avatar_box.set_icon_id(player_state.icon_id)
    avatar_box.set_hexagon_modulate(_color_from_id(player_state.color_id))
    display_name_label.text = _resolved_display_name(player_state)
    display_name_label.remove_theme_color_override("font_color")
    _fiat_balance = player_state.fiat_balance
    _energy_amount = player_state.energy_amount
    _bitcoin_balance = player_state.bitcoin_balance
    _sync_resource_labels()

func set_is_current_turn_player(is_current_turn_player: bool) -> void:
    background_highlight.visible = is_current_turn_player

func set_resource_leader_markers(
    is_fiat_leader: bool,
    is_energy_leader: bool,
    is_bitcoin_leader: bool
) -> void:
    _is_fiat_leader = is_fiat_leader
    _is_energy_leader = is_energy_leader
    _is_bitcoin_leader = is_bitcoin_leader
    _sync_resource_labels()

func _sync_resource_labels() -> void:
    if not is_node_ready():
        return
    fiat_icon_label.text = _resource_icon(_is_fiat_leader, "$")
    fiat_value_label.text = "%.2f" % _fiat_balance
    energy_icon_label.text = _resource_icon(_is_energy_leader, "⚡")
    energy_value_label.text = "%d" % _energy_amount
    bitcoin_icon_label.text = _resource_icon(_is_bitcoin_leader, "₿")
    bitcoin_value_label.text = "%.1f/%.0f" % [_bitcoin_balance, GameEconomyConfigModel.BITCOIN_GOAL_TO_WIN]

func _resource_icon(is_leader: bool, default_icon: String) -> String:
    if is_leader:
        return "🥇"
    return default_icon

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
