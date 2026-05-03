class_name EventLogPanel
extends MarginContainer

const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")
const EventLogItemScene = preload("res://scenes/game/hud/event_log_item.tscn")
const MAX_VISIBLE_MESSAGES: int = 21
const ICON_PREFIXES: Array[String] = ["🚦", "🔄", "🎮️", "🎮", "🎲", "📍", "⚠️", "⚠"]
const NEUTRAL_BACKGROUND_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)
const PLAYER_BACKGROUND_ALPHA: float = 0.42
const PLAYER_BACKGROUND_DARKEN_AMOUNT: float = 0.58

@onready var toggle_button: Button = get_node(^"VBoxContainer/ContainerIcon/EventLogToggleButton")
@onready var event_list: MarginContainer = get_node(^"VBoxContainer/EventList")
@onready var scroll_container: ScrollContainer = get_node(^"VBoxContainer/EventList/ScrollContainer")
@onready var items_container: VBoxContainer = get_node(^"VBoxContainer/EventList/ScrollContainer/VBoxContainer")

func _ready() -> void:
    assert(toggle_button)
    assert(event_list)
    assert(scroll_container)
    assert(items_container)
    toggle_button.pressed.connect(_on_toggle_button_pressed)
    _initialize_event_items()
    _sync_collapsed_state()
    set_messages([])

func set_messages(messages: Array) -> void:
    if not is_node_ready():
        call_deferred("set_messages", messages.duplicate())
        return

    var visible_messages: Array = messages
    if visible_messages.size() > MAX_VISIBLE_MESSAGES:
        visible_messages = visible_messages.slice(
            visible_messages.size() - MAX_VISIBLE_MESSAGES,
            visible_messages.size()
        )
    visible_messages.reverse()

    var item_count: int = items_container.get_child_count()
    for item_index in range(item_count):
        var item: MarginContainer = items_container.get_child(item_index)
        assert(item)
        var background_panel: Panel = item.get_node(^"Panel")
        var icon_label: Label = item.get_node(^"HBoxContainer/Icon")
        var message_label: Label = item.get_node(^"HBoxContainer/Message")
        assert(background_panel)
        assert(icon_label)
        assert(message_label)
        if item_index < visible_messages.size():
            var event_entry: Variant = visible_messages[item_index]
            var message: String = _entry_message(event_entry)
            icon_label.text = _event_icon(message)
            message_label.text = _event_text(message)
            _apply_background_color(background_panel, _entry_color_id(event_entry))
            item.visible = true
            continue
        icon_label.text = ""
        message_label.text = ""
        item.visible = false

    _queue_scroll_to_top()

func _initialize_event_items() -> void:
    for child in items_container.get_children():
        items_container.remove_child(child)
        child.queue_free()

    for _item_index in range(MAX_VISIBLE_MESSAGES):
        var item: Node = EventLogItemScene.instantiate()
        items_container.add_child(item)

func _event_icon(message: String) -> String:
    for icon: String in ICON_PREFIXES:
        if message.begins_with(icon):
            return icon
    if message.contains(" rolled "):
        return "🎲"
    if message.contains(" landed on "):
        return "📍"
    if message.begins_with("Action rejected:"):
        return "⚠️"
    return ""

func _event_text(message: String) -> String:
    for icon: String in ICON_PREFIXES:
        if message.begins_with(icon):
            return message.substr(icon.length()).strip_edges()
    return message

func _entry_message(event_entry: Variant) -> String:
    if event_entry is Dictionary:
        var event_dictionary: Dictionary = event_entry
        return str(event_dictionary.get("message", ""))
    return str(event_entry)

func _entry_color_id(event_entry: Variant) -> int:
    if not event_entry is Dictionary:
        return -1
    var event_dictionary: Dictionary = event_entry
    return int(event_dictionary.get("color_id", -1))

func _apply_background_color(background_panel: Panel, color_id: int) -> void:
    var background_color: Color = NEUTRAL_BACKGROUND_COLOR
    if color_id >= 0 and color_id < PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size():
        background_color = PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[color_id].darkened(
            PLAYER_BACKGROUND_DARKEN_AMOUNT
        )
        background_color.a = PLAYER_BACKGROUND_ALPHA

    var style_box: StyleBoxFlat = background_panel.get_theme_stylebox("panel").duplicate()
    style_box.bg_color = background_color
    background_panel.add_theme_stylebox_override("panel", style_box)

func _on_toggle_button_pressed() -> void:
    if event_list.visible == true:
        _set_expanded(false)
        return
    _set_expanded(true)

func _sync_collapsed_state() -> void:
    _set_expanded(event_list.visible)

func _set_expanded(is_expanded: bool) -> void:
    if is_expanded == true:
        size_flags_vertical = Control.SIZE_EXPAND_FILL
        event_list.visible = true
        _queue_scroll_to_top()
        return
    size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    event_list.visible = false

func _queue_scroll_to_top() -> void:
    call_deferred("_scroll_to_top_after_layout")

func _scroll_to_top_after_layout() -> void:
    await get_tree().process_frame
    _scroll_to_top()

func _scroll_to_top() -> void:
    var vertical_scroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
    assert(vertical_scroll_bar)
    scroll_container.scroll_vertical = 0
