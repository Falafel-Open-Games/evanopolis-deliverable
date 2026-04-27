class_name IdentityColorPicker
extends HBoxContainer

const CHECK_NODE_PATH: NodePath = ^"check"
const PENDING_CHECK_NODE_PATH: NodePath = ^"pending_check"

signal color_selected(color_id: int)

var _color_group: ButtonGroup
var _buttons_by_color_id: Array[BaseButton] = []
var _authoritative_color_id: int = PlayerIdentityCard.DEFAULT_COLOR_ID
var _selected_color_id: int = 0
var _disabled_color_ids: Dictionary = { }

func _ready() -> void:
    assert(get_child_count() == PlayerIdentityCard.PLAYER_REPRESENTATION_COLORS.size())
    _color_group = ButtonGroup.new()
    for child_index in range(get_child_count()):
        var child: Node = get_child(child_index)
        var button: BaseButton = child as BaseButton
        assert(button)
        var authoritative_check: CanvasItem = button.get_node(CHECK_NODE_PATH)
        var pending_check: CanvasItem = button.get_node(PENDING_CHECK_NODE_PATH)
        assert(authoritative_check)
        assert(pending_check)
        button.toggle_mode = true
        button.button_group = _color_group
        button.set_meta("color_id", child_index)
        button.self_modulate = PlayerIdentityCard.PLAYER_REPRESENTATION_COLORS[child_index]
        authoritative_check.visible = false
        pending_check.visible = false
        _buttons_by_color_id.append(button)
    _color_group.pressed.connect(_on_color_pressed)
    set_authoritative_color_id(PlayerIdentityCard.DEFAULT_COLOR_ID)
    set_selected_color_id(PlayerIdentityCard.DEFAULT_COLOR_ID)

func get_authoritative_color_id() -> int:
    return _authoritative_color_id

func get_selected_color_id() -> int:
    return _selected_color_id

func set_authoritative_color_id(color_id: int) -> void:
    assert(color_id >= 0 and color_id < _buttons_by_color_id.size())
    _authoritative_color_id = color_id
    _sync_visual_state()
    _sync_disabled_state()

func set_selected_color_id(color_id: int) -> void:
    assert(color_id >= 0 and color_id < _buttons_by_color_id.size())
    _selected_color_id = color_id
    _sync_visual_state()
    _sync_disabled_state()

func set_disabled_color_ids(color_ids: Array) -> void:
    _disabled_color_ids.clear()
    for color_id_variant in color_ids:
        var color_id: int = int(color_id_variant)
        if color_id < 0 or color_id >= _buttons_by_color_id.size():
            continue
        _disabled_color_ids[color_id] = true
    if _selected_color_id != _authoritative_color_id and bool(_disabled_color_ids.get(_selected_color_id, false)):
        _selected_color_id = _authoritative_color_id
        _sync_visual_state()
        _sync_disabled_state()
        color_selected.emit(_selected_color_id)
        return
    _sync_disabled_state()

func _on_color_pressed(button: BaseButton) -> void:
    var color_id: int = int(button.get_meta("color_id", -1))
    assert(color_id >= 0 and color_id < _buttons_by_color_id.size())
    _selected_color_id = color_id
    _sync_visual_state()
    color_selected.emit(color_id)

func _sync_visual_state() -> void:
    for color_id in range(_buttons_by_color_id.size()):
        var button: BaseButton = _buttons_by_color_id[color_id]
        var authoritative_check: CanvasItem = button.get_node(CHECK_NODE_PATH)
        var pending_check: CanvasItem = button.get_node(PENDING_CHECK_NODE_PATH)
        button.set_pressed_no_signal(color_id == _selected_color_id)
        authoritative_check.visible = color_id == _authoritative_color_id
        pending_check.visible = (
            color_id == _selected_color_id
            and _selected_color_id != _authoritative_color_id
        )

func _sync_disabled_state() -> void:
    for color_id in range(_buttons_by_color_id.size()):
        var button: BaseButton = _buttons_by_color_id[color_id]
        var is_disabled: bool = (
            bool(_disabled_color_ids.get(color_id, false))
            and color_id != _selected_color_id
            and color_id != _authoritative_color_id
        )
        button.disabled = is_disabled
        button.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_disabled else Control.CURSOR_POINTING_HAND
