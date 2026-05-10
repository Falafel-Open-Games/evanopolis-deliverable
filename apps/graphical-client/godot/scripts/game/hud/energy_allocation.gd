class_name EnergyAllocationView
extends MarginContainer

signal allocation_requested(sell_percent: int)

@onready var sell_vs_mine_slider: HSlider = get_node(^"MarginContainer/VBoxContainer/SellVsMineSlider")
@onready var submit_allocation_button: Button = get_node(^"MarginContainer/VBoxContainer/SubmitAllocationButton")
@onready var energy_preview_label: Label = get_node(^"MarginContainer/VBoxContainer/HBoxContainer2/EnergyPreview")
@onready var mine_preview_label: Label = get_node(^"MarginContainer/VBoxContainer/HBoxContainer2/MinePreview")

var _current_sell_100_fiat_total: float = 0.0
var _current_mine_100_btc_total: float = 0.0
var _accepted_sell_percent: int = 50
var _can_submit_allocation: bool = false
var _ignore_slider_value_changed: bool = false
var _is_available: bool = false
var _is_open: bool = false

func _ready() -> void:
    assert(sell_vs_mine_slider)
    assert(submit_allocation_button)
    assert(energy_preview_label)
    assert(mine_preview_label)
    visible = false
    sell_vs_mine_slider.value_changed.connect(_on_sell_vs_mine_slider_value_changed)
    submit_allocation_button.pressed.connect(_on_submit_allocation_button_pressed)
    set_energy_allocation_state(50, false, 0.0, 0.0, false, false)

func set_energy_allocation_state(
    sell_percent: int,
    can_edit: bool,
    sell_100_fiat_total: float,
    mine_100_btc_total: float,
    is_request_pending: bool,
    should_show: bool
) -> void:
    if not is_node_ready():
        call_deferred(
            "set_energy_allocation_state",
            sell_percent,
            can_edit,
            sell_100_fiat_total,
            mine_100_btc_total,
            is_request_pending,
            should_show
        )
        return
    _is_available = (
        should_show
        or can_edit
        or is_request_pending
        or sell_100_fiat_total > 0.0
        or mine_100_btc_total > 0.0
    )
    visible = _is_available and _is_open
    _accepted_sell_percent = clampi(sell_percent, 0, 100)
    _current_sell_100_fiat_total = maxf(0.0, sell_100_fiat_total)
    _current_mine_100_btc_total = maxf(0.0, mine_100_btc_total)
    _can_submit_allocation = can_edit and not is_request_pending
    sell_vs_mine_slider.editable = _can_submit_allocation
    _ignore_slider_value_changed = true
    sell_vs_mine_slider.value = _accepted_sell_percent
    _ignore_slider_value_changed = false
    _update_energy_allocation_previews(_accepted_sell_percent)
    _update_submit_allocation_button()

func set_panel_open(is_open: bool) -> void:
    _is_open = is_open and _is_available
    visible = _is_available and _is_open

func is_panel_open() -> bool:
    return _is_open

func is_panel_available() -> bool:
    return _is_available

func _on_sell_vs_mine_slider_value_changed(value: float) -> void:
    if _ignore_slider_value_changed:
        return
    _update_energy_allocation_previews(int(round(value)))
    _update_submit_allocation_button()

func _on_submit_allocation_button_pressed() -> void:
    var requested_sell_percent: int = int(round(sell_vs_mine_slider.value))
    if not _can_submit_allocation:
        return
    if requested_sell_percent == _accepted_sell_percent:
        return
    allocation_requested.emit(requested_sell_percent)

func _update_energy_allocation_previews(sell_percent: int) -> void:
    var normalized_sell_percent: int = clampi(sell_percent, 0, 100)
    var mine_percent: int = 100 - normalized_sell_percent
    var fiat_per_turn: float = _current_sell_100_fiat_total * (float(normalized_sell_percent) / 100.0)
    var bitcoin_per_turn: float = _current_mine_100_btc_total * (float(mine_percent) / 100.0)
    energy_preview_label.text = "%d%% → $ %s" % [
        normalized_sell_percent,
        _format_preview_amount(fiat_per_turn, 2),
    ]
    mine_preview_label.text = "%d%% → ₿ %s" % [
        mine_percent,
        _format_preview_amount(bitcoin_per_turn, 4),
    ]

func _update_submit_allocation_button() -> void:
    var has_pending_change: bool = int(round(sell_vs_mine_slider.value)) != _accepted_sell_percent
    submit_allocation_button.visible = _can_submit_allocation
    submit_allocation_button.disabled = not has_pending_change

func _format_preview_amount(value: float, decimals: int) -> String:
    var text: String = String.num(value, decimals)
    while text.contains(".") and (text.ends_with("0") or text.ends_with(".")):
        if text.ends_with("."):
            text = text.substr(0, text.length() - 1)
            break
        text = text.substr(0, text.length() - 1)
    return text

func should_show_in_intro() -> bool:
    return visible
