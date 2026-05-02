class_name EventLogPanel
extends MarginContainer

const MAX_VISIBLE_MESSAGES: int = 6

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

    var item_count: int = items_container.get_child_count()
    for item_index in range(item_count):
        var item: MarginContainer = items_container.get_child(item_index)
        assert(item)
        var label: Label = item.get_node(^"Label")
        assert(label)
        if item_index < visible_messages.size():
            label.text = str(visible_messages[item_index])
            item.visible = true
            continue
        label.text = ""
        item.visible = false

    call_deferred("_scroll_to_bottom")

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
        call_deferred("_scroll_to_bottom")
        return
    size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    event_list.visible = false

func _scroll_to_bottom() -> void:
    var vertical_scroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
    assert(vertical_scroll_bar)
    scroll_container.scroll_vertical = int(vertical_scroll_bar.max_value)
