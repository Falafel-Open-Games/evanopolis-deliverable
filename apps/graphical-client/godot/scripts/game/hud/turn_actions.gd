class_name TurnActionsView
extends MarginContainer

const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")
const CITY_TEXTURES: Dictionary = {
    "Angra dos Reis": preload("res://assets/cities/3.Angra dos Reis.png"),
    "Atacama": preload("res://assets/cities/5.Atacama.png"),
    "Ciudad del Este": preload("res://assets/cities/1.Ciudad del Este.png"),
    "El Salvador": preload("res://assets/cities/4.El Salvador.png"),
    "Irkutsk": preload("res://assets/cities/2.Irkutsk.png"),
    "Patagonia": preload("res://assets/cities/6.Patagonia.png"),
}
const DEBUG_GAMEPLAY_ARGUMENT: String = "--debug"

signal roll_dice_requested()
signal end_turn_requested()
signal buy_property_requested(tile_index: int)
signal pay_toll_requested()

@onready var roll_dice_button: Button = get_node(^"ContentContainer/VBoxContainer/RollDice")
@onready var property_actions: Control = get_node(^"ContentContainer/VBoxContainer/PropertyActions")
@onready var city_texture: TextureRect = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/CityTexture")
@onready var tile_title_label: Label = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/TitleContainer/TileTitle")
@onready var buy_overlay: Control = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/BuyOverlay")
@onready var toll_overlay: Control = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/TollOverlay")
@onready var owner_color_texture: TextureRect = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/TollOverlay/VBoxContainer/Owner/OwnerColor/TextureRect")
@onready var owner_value_label: Label = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/TollOverlay/VBoxContainer/Owner/OwnerValue")
@onready var toll_price_row: Control = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/TollOverlay/VBoxContainer/Toll")
@onready var energy_value_label: Label = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/BuyOverlay/VBoxContainer/Produces/EnergyValueLabel")
@onready var sell_value_label: Label = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/BuyOverlay/VBoxContainer/SellEnergy/SellValueLabel")
@onready var mine_value_label: Label = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/BuyOverlay/VBoxContainer/UseEnergy/MineValueLabel")
@onready var buy_price_value_label: Label = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/BuyOverlay/VBoxContainer/BuyPrice/BuyPriceValueLabel")
@onready var toll_price_value_label: Label = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/CityInfoCard/OverlayMargin/InfoPanel/TollOverlay/VBoxContainer/Toll/TollPriceValueLabel")
@onready var buy_pass_container: Control = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/BuyPassContainer")
@onready var pass_button: Button = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/BuyPassContainer/Pass")
@onready var buy_button: Button = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/BuyPassContainer/Buy")
@onready var pay_toll_button: Button = get_node(^"ContentContainer/VBoxContainer/PropertyActions/VBoxContainer/PayToll")
@onready var sell_vs_mine_slider: HSlider = get_node(^"ContentContainer/VBoxContainer/SellVsMineSlider")
@onready var end_turn_button: Button = get_node(^"ContentContainer/VBoxContainer/EndTurn")

var _current_property_action_tile_index: int = -1
var _current_can_end_turn: bool = false

func _ready() -> void:
    assert(roll_dice_button)
    assert(property_actions)
    assert(city_texture)
    assert(tile_title_label)
    assert(buy_overlay)
    assert(toll_overlay)
    assert(owner_color_texture)
    assert(owner_value_label)
    assert(toll_price_row)
    assert(energy_value_label)
    assert(sell_value_label)
    assert(mine_value_label)
    assert(buy_price_value_label)
    assert(toll_price_value_label)
    assert(buy_pass_container)
    assert(pass_button)
    assert(buy_button)
    assert(pay_toll_button)
    assert(sell_vs_mine_slider)
    assert(end_turn_button)
    roll_dice_button.pressed.connect(_on_roll_dice_pressed)
    pass_button.pressed.connect(_on_pass_pressed)
    buy_button.pressed.connect(_on_buy_pressed)
    pay_toll_button.pressed.connect(_on_pay_toll_pressed)
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    set_turn_action_state(false, false, false, { })

func set_turn_action_state(
        can_roll_dice: bool,
        can_end_turn: bool,
        is_local_turn: bool,
        property_action: Dictionary = { }
) -> void:
    if not is_node_ready():
        call_deferred(
            "set_turn_action_state",
            can_roll_dice,
            can_end_turn,
            is_local_turn,
            property_action.duplicate(true)
        )
        return
    visible = is_local_turn
    roll_dice_button.visible = can_roll_dice
    roll_dice_button.disabled = not can_roll_dice
    sell_vs_mine_slider.editable = false
    _current_can_end_turn = can_end_turn
    end_turn_button.visible = can_end_turn
    end_turn_button.disabled = not can_end_turn
    _set_property_action_state(property_action)

func _on_roll_dice_pressed() -> void:
    roll_dice_button.disabled = true
    roll_dice_requested.emit()

func _on_end_turn_pressed() -> void:
    end_turn_button.disabled = true
    end_turn_requested.emit()

func _set_property_action_state(property_action: Dictionary) -> void:
    property_actions.visible = not property_action.is_empty()
    _debug_print_property_actions_visibility(property_action)
    if property_action.is_empty():
        _current_property_action_tile_index = -1
        return

    var action_type: String = str(property_action.get("action_type", ""))
    var can_buy_property: bool = bool(property_action.get("can_buy_property", action_type == "buy_or_end_turn"))
    var can_afford_buy_property: bool = bool(property_action.get("can_afford_buy_property", true))
    var can_pay_toll: bool = bool(property_action.get("can_pay_toll", action_type == "pay_toll"))
    var can_afford_pay_toll: bool = bool(property_action.get("can_afford_pay_toll", true))
    var show_bitcoin_toll_price: bool = bool(property_action.get("show_bitcoin_toll_price", false))
    var show_buy_overlay: bool = bool(property_action.get("show_buy_overlay", false))
    var show_toll_overlay: bool = bool(property_action.get("show_toll_overlay", false))
    var show_toll_price: bool = bool(property_action.get("show_toll_price", false))
    var owner_name: String = str(property_action.get("owner_name", "")).strip_edges()
    var owner_color_id: int = int(property_action.get("owner_color_id", PlayerIdentityCardView.DEFAULT_COLOR_ID))
    var city_name: String = str(property_action.get("city", "")).strip_edges()
    var tile_type: String = str(property_action.get("tile_type", "")).strip_edges()
    var tile_index: int = int(property_action.get("tile_index", -1))
    _current_property_action_tile_index = tile_index
    var title: String = city_name
    if title.is_empty():
        title = "Tile %d" % tile_index
    if not tile_type.is_empty():
        title = "%s (%s)" % [title, tile_type]
    tile_title_label.text = title

    var texture_variant: Variant = CITY_TEXTURES.get(city_name, null)
    if texture_variant is Texture2D:
        city_texture.texture = texture_variant

    energy_value_label.text = "%d energy" % int(property_action.get("energy_production", 0))
    sell_value_label.text = "$ %s / turn" % _format_amount(float(property_action.get("sell_100_fiat", 0.0)))
    mine_value_label.text = "BTC %s / turn" % _format_amount(float(property_action.get("mine_100_btc", 0.0)))
    buy_price_value_label.text = "$ %s" % _format_amount(float(property_action.get("buy_price", 0.0)))
    owner_value_label.text = owner_name if not owner_name.is_empty() else "Player"
    owner_value_label.add_theme_color_override("font_color", Color.WHITE)
    owner_color_texture.modulate = _player_color_from_id(owner_color_id)
    if show_bitcoin_toll_price:
        toll_price_value_label.text = "₿ 1.00"
    else:
        toll_price_value_label.text = "$ %s" % _format_amount(float(property_action.get("toll_due", 0.0)))

    buy_overlay.visible = show_buy_overlay
    toll_overlay.visible = show_toll_overlay
    toll_price_row.visible = show_toll_price
    buy_pass_container.visible = action_type == "buy_or_end_turn"
    pass_button.disabled = not buy_pass_container.visible or tile_index < 0
    buy_button.visible = buy_pass_container.visible and can_afford_buy_property
    buy_button.disabled = not buy_button.visible or not can_buy_property or tile_index < 0
    pay_toll_button.visible = action_type == "pay_toll"
    pay_toll_button.disabled = not pay_toll_button.visible or not can_pay_toll or not can_afford_pay_toll or tile_index < 0
    var show_acknowledge_defeat_button: bool = action_type == "pay_toll" and not can_afford_pay_toll
    end_turn_button.visible = action_type == "end_turn" or show_acknowledge_defeat_button
    end_turn_button.disabled = not end_turn_button.visible or not _current_can_end_turn

func _on_pass_pressed() -> void:
    if _current_property_action_tile_index < 0:
        return
    pass_button.disabled = true
    end_turn_requested.emit()

func _on_buy_pressed() -> void:
    if _current_property_action_tile_index < 0:
        return
    buy_button.disabled = true
    buy_property_requested.emit(_current_property_action_tile_index)

func _on_pay_toll_pressed() -> void:
    pay_toll_button.disabled = true
    pay_toll_requested.emit()

func _format_amount(value: float) -> String:
    if is_equal_approx(value, round(value)):
        return "%d" % int(round(value))
    return "%.2f" % value

func _player_color_from_id(color_id: int) -> Color:
    if color_id < 0 or color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size():
        return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[PlayerIdentityCardView.DEFAULT_COLOR_ID]
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[color_id]

func _debug_print_property_actions_visibility(property_action: Dictionary) -> void:
    if not _should_print_debug_gameplay_state():
        return
    print(
        "[visible:property_actions] visible=%s empty=%s action=%s tile=%d type=%s city=%s size=%s"
        % [
            property_actions.visible,
            property_action.is_empty(),
            str(property_action.get("action_type", "")),
            int(property_action.get("tile_index", -1)),
            str(property_action.get("tile_type", "")),
            str(property_action.get("city", "")),
            str(property_actions.size),
        ]
    )

func _should_print_debug_gameplay_state() -> bool:
    return OS.has_environment("EVANOPOLIS_DEBUG_GAMEPLAY") or _has_debug_argument()

func _has_debug_argument() -> bool:
    for argument in OS.get_cmdline_args():
        if argument == DEBUG_GAMEPLAY_ARGUMENT or argument.begins_with("%s=" % DEBUG_GAMEPLAY_ARGUMENT):
            return true
    for argument in OS.get_cmdline_user_args():
        if argument == DEBUG_GAMEPLAY_ARGUMENT or argument.begins_with("%s=" % DEBUG_GAMEPLAY_ARGUMENT):
            return true
    return false
