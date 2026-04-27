class_name PlayerIdentityEditorUI
extends MarginContainer

const PREVIEW_CARD_PATH: NodePath = ^"vbox/MarginContainer/HBoxContainer/Preview Card/PlayerIdentityCardRoot"
const DISPLAY_NAME_LINE_EDIT_PATH: NodePath = ^"vbox/MarginContainer/HBoxContainer/Name and Color/LineEdit"
const COLOR_PICKER_PATH: NodePath = ^"vbox/MarginContainer/HBoxContainer/Name and Color/HBoxContainer"
const PREV_ICON_BUTTON_PATH: NodePath = ^"vbox/MarginContainer2/HBoxContainer3/PrevIconButton"
const CAROUSEL_VIEWPORT_PATH: NodePath = ^"vbox/MarginContainer2/HBoxContainer3/CarouselViewport"
const ICON_STRIP_PATH: NodePath = ^"vbox/MarginContainer2/HBoxContainer3/CarouselViewport/ClipRoot/IconStrip"
const NEXT_ICON_BUTTON_PATH: NodePath = ^"vbox/MarginContainer2/HBoxContainer3/NextIconButton"
const SAVE_BUTTON_PATH: NodePath = ^"vbox/HBoxContainer2/SaveButton"
const ICON_SPRITE_NODE_PATH: NodePath = ^"IconSprite"
const MAX_DISPLAY_NAME_LENGTH: int = 12
const VISIBLE_ICON_COUNT: int = 6
const SELECTED_ICON_SCALE: Vector2 = Vector2(0.34, 0.34)
const UNSELECTED_ICON_SCALE: Vector2 = Vector2(0.30, 0.30)
const SELECTED_ICON_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const UNSELECTED_ICON_TINT: Color = Color(1.0, 1.0, 1.0, 0.72)

signal identity_draft_changed(display_name: String, color_id: int)
signal identity_save_requested(display_name: String, icon_id: int, color_id: int)

@onready var preview_card: PlayerIdentityCard = get_node(PREVIEW_CARD_PATH)
@onready var display_name_line_edit: LineEdit = get_node(DISPLAY_NAME_LINE_EDIT_PATH)
@onready var color_picker: IdentityColorPicker = get_node(COLOR_PICKER_PATH)
@onready var prev_icon_button: Button = get_node(PREV_ICON_BUTTON_PATH)
@onready var carousel_viewport: Control = get_node(CAROUSEL_VIEWPORT_PATH)
@onready var icon_strip: HBoxContainer = get_node(ICON_STRIP_PATH)
@onready var next_icon_button: Button = get_node(NEXT_ICON_BUTTON_PATH)
@onready var save_button: Button = get_node(SAVE_BUTTON_PATH)

var _local_player_id: String = ""
var _selected_icon_id: int = PlayerIdentityCard.DEFAULT_ICON_FRAME
var _authoritative_display_name: String = ""
var _authoritative_icon_id: int = PlayerIdentityCard.DEFAULT_ICON_FRAME
var _authoritative_color_id: int = PlayerIdentityCard.DEFAULT_COLOR_ID
var _has_authoritative_identity: bool = false
var _has_local_draft_changes: bool = false
var _save_enabled_by_parent: bool = true
var _syncing_authoritative_identity: bool = false
var _icon_choice_controls: Array[Control] = []
var _icon_choice_sprites: Array[Sprite2D] = []
var _icon_scroll_index: int = 0

func _ready() -> void:
    assert(preview_card)
    assert(display_name_line_edit)
    assert(color_picker)
    assert(prev_icon_button)
    assert(carousel_viewport)
    assert(icon_strip)
    assert(next_icon_button)
    assert(save_button)

    display_name_line_edit.max_length = MAX_DISPLAY_NAME_LENGTH
    display_name_line_edit.text_changed.connect(_on_display_name_text_changed)
    color_picker.color_selected.connect(_on_color_selected)
    prev_icon_button.pressed.connect(_on_prev_icon_button_pressed)
    next_icon_button.pressed.connect(_on_next_icon_button_pressed)
    save_button.pressed.connect(_on_save_button_pressed)
    _setup_icon_picker()
    _emit_identity_draft()
    _update_local_draft_state()
    _refresh_save_button_enabled()
    call_deferred("_refresh_icon_picker_layout")

func _on_display_name_text_changed(new_text: String) -> void:
    if new_text.length() > MAX_DISPLAY_NAME_LENGTH:
        display_name_line_edit.text = new_text.substr(0, MAX_DISPLAY_NAME_LENGTH)
        display_name_line_edit.caret_column = display_name_line_edit.text.length()
    if _syncing_authoritative_identity:
        return
    _emit_identity_draft()
    _update_local_draft_state()
    _refresh_save_button_enabled()

func _on_color_selected(_color_id: int) -> void:
    if _syncing_authoritative_identity:
        return
    _emit_identity_draft()
    _update_local_draft_state()
    _refresh_save_button_enabled()

func _on_prev_icon_button_pressed() -> void:
    if _icon_scroll_index <= 0:
        return
    _icon_scroll_index -= 1
    _update_icon_strip_position()

func _on_next_icon_button_pressed() -> void:
    if _icon_scroll_index >= _max_icon_scroll_index():
        return
    _icon_scroll_index += 1
    _update_icon_strip_position()

func set_local_player_id(player_id: String) -> void:
    _local_player_id = player_id
    if is_node_ready():
        _emit_identity_draft()

func sync_authoritative_identity(player_id: String, display_name: String, icon_id: int, color_id: int) -> void:
    _local_player_id = player_id
    _authoritative_display_name = display_name.strip_edges()
    _authoritative_icon_id = icon_id if icon_id >= 0 else PlayerIdentityCard.DEFAULT_ICON_FRAME
    _authoritative_color_id = color_id if color_id >= 0 else PlayerIdentityCard.DEFAULT_COLOR_ID
    color_picker.set_authoritative_color_id(_authoritative_color_id)
    if not _has_local_draft_changes:
        _apply_authoritative_identity_to_inputs()
    elif _matches_authoritative_identity():
        _has_local_draft_changes = false
    _has_authoritative_identity = true
    _emit_identity_draft()
    _update_local_draft_state()
    _refresh_save_button_enabled()

func set_save_enabled(is_enabled: bool) -> void:
    _save_enabled_by_parent = is_enabled
    if is_node_ready():
        _refresh_save_button_enabled()

func set_unavailable_color_ids(color_ids: Array) -> void:
    color_picker.set_disabled_color_ids(color_ids)

func _on_save_button_pressed() -> void:
    var display_name: String = display_name_line_edit.text.strip_edges()
    if display_name.is_empty():
        return
    identity_save_requested.emit(display_name, _selected_icon_id, color_picker.get_selected_color_id())

func _emit_identity_draft() -> void:
    var display_name: String = display_name_line_edit.text.strip_edges()
    var preview_name: String = display_name
    if preview_name.is_empty():
        preview_name = "Player"
    var color_id: int = color_picker.get_selected_color_id()
    preview_card.set_identity(
        preview_name,
        _short_player_id(_local_player_id),
        _selected_icon_id,
        color_id
    )
    identity_draft_changed.emit(display_name, color_id)

func _short_player_id(player_id: String) -> String:
    if player_id.is_empty():
        return "No player id yet"
    if player_id.length() <= 18:
        return player_id
    return "%s...%s" % [player_id.substr(0, 8), player_id.substr(player_id.length() - 6, 6)]

func _apply_authoritative_identity_to_inputs() -> void:
    _syncing_authoritative_identity = true
    display_name_line_edit.text = _authoritative_display_name
    display_name_line_edit.caret_column = display_name_line_edit.text.length()
    color_picker.set_authoritative_color_id(_authoritative_color_id)
    color_picker.set_selected_color_id(_authoritative_color_id)
    _set_selected_icon_id(_authoritative_icon_id, true)
    _syncing_authoritative_identity = false
    _has_local_draft_changes = false

func _has_unsaved_changes() -> bool:
    if not _has_authoritative_identity:
        return not display_name_line_edit.text.strip_edges().is_empty()
    return (
        display_name_line_edit.text.strip_edges() != _authoritative_display_name
        or color_picker.get_selected_color_id() != _authoritative_color_id
        or _selected_icon_id != _authoritative_icon_id
    )

func _matches_authoritative_identity() -> bool:
    return (
        display_name_line_edit.text.strip_edges() == _authoritative_display_name
        and color_picker.get_selected_color_id() == _authoritative_color_id
        and _selected_icon_id == _authoritative_icon_id
    )

func _update_local_draft_state() -> void:
    _has_local_draft_changes = _has_unsaved_changes()

func _refresh_save_button_enabled() -> void:
    var has_display_name: bool = not display_name_line_edit.text.strip_edges().is_empty()
    save_button.disabled = not (_save_enabled_by_parent and has_display_name and _has_unsaved_changes())

func _setup_icon_picker() -> void:
    _icon_choice_controls.clear()
    _icon_choice_sprites.clear()
    for child_index in range(icon_strip.get_child_count()):
        var icon_choice: Control = icon_strip.get_child(child_index) as Control
        assert(icon_choice)
        var icon_sprite: Sprite2D = icon_choice.get_node(ICON_SPRITE_NODE_PATH) as Sprite2D
        assert(icon_sprite)
        icon_choice.mouse_filter = Control.MOUSE_FILTER_STOP
        icon_choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        icon_choice.gui_input.connect(_on_icon_choice_gui_input.bind(child_index))
        icon_sprite.frame = child_index
        _icon_choice_controls.append(icon_choice)
        _icon_choice_sprites.append(icon_sprite)
    assert(_icon_choice_sprites.size() > PlayerIdentityCard.DEFAULT_ICON_FRAME)
    _refresh_icon_selection_visuals()

func _refresh_icon_picker_layout() -> void:
    _sync_icon_strip_width()
    _ensure_selected_icon_visible()
    _update_icon_strip_position()

func _on_icon_choice_gui_input(event: InputEvent, icon_id: int) -> void:
    var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
    if mouse_button_event == null:
        return
    if not mouse_button_event.pressed:
        return
    if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
        return
    _set_selected_icon_id(icon_id, true)
    if _syncing_authoritative_identity:
        return
    _emit_identity_draft()
    _update_local_draft_state()
    _refresh_save_button_enabled()

func _set_selected_icon_id(icon_id: int, should_adjust_scroll: bool) -> void:
    assert(icon_id >= 0 and icon_id < _icon_choice_sprites.size())
    _selected_icon_id = icon_id
    if should_adjust_scroll:
        _ensure_selected_icon_visible()
        _update_icon_strip_position()
    _refresh_icon_selection_visuals()

func _refresh_icon_selection_visuals() -> void:
    for icon_id in range(_icon_choice_controls.size()):
        var icon_choice: Control = _icon_choice_controls[icon_id]
        var icon_sprite: Sprite2D = _icon_choice_sprites[icon_id]
        var is_selected: bool = icon_id == _selected_icon_id
        icon_choice.modulate = SELECTED_ICON_TINT if is_selected else UNSELECTED_ICON_TINT
        icon_sprite.scale = SELECTED_ICON_SCALE if is_selected else UNSELECTED_ICON_SCALE

func _ensure_selected_icon_visible() -> void:
    var max_scroll_index: int = _max_icon_scroll_index()
    if _selected_icon_id < _icon_scroll_index:
        _icon_scroll_index = _selected_icon_id
    elif _selected_icon_id >= _icon_scroll_index + VISIBLE_ICON_COUNT:
        _icon_scroll_index = _selected_icon_id - VISIBLE_ICON_COUNT + 1
    _icon_scroll_index = clampi(_icon_scroll_index, 0, max_scroll_index)

func _update_icon_strip_position() -> void:
    var target_offset: float = float(_icon_scroll_index) * _icon_step()
    var applied_offset: float = minf(target_offset, _max_icon_scroll_offset())
    icon_strip.position.x = -applied_offset
    _refresh_icon_navigation_state()

func _refresh_icon_navigation_state() -> void:
    var can_scroll_backward: bool = _icon_scroll_index > 0
    var current_offset: float = -icon_strip.position.x
    var can_scroll_forward: bool = current_offset < _max_icon_scroll_offset() - 0.5
    prev_icon_button.disabled = not can_scroll_backward
    next_icon_button.disabled = not can_scroll_forward
    prev_icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_scroll_backward else Control.CURSOR_ARROW
    next_icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_scroll_forward else Control.CURSOR_ARROW

func _sync_icon_strip_width() -> void:
    if _icon_choice_controls.is_empty():
        return
    var child_width: float = _icon_choice_controls[0].custom_minimum_size.x
    if child_width <= 0.0:
        child_width = _icon_choice_controls[0].size.x
    var total_width: float = float(_icon_choice_controls.size()) * child_width
    total_width += float(max(_icon_choice_controls.size() - 1, 0)) * float(icon_strip.get_theme_constant("separation"))
    var current_minimum_size: Vector2 = icon_strip.custom_minimum_size
    icon_strip.custom_minimum_size = Vector2(total_width, current_minimum_size.y)

func _icon_step() -> float:
    if _icon_choice_controls.is_empty():
        return 0.0
    var child_width: float = _icon_choice_controls[0].custom_minimum_size.x
    if child_width <= 0.0:
        child_width = _icon_choice_controls[0].size.x
    return child_width + float(icon_strip.get_theme_constant("separation"))

func _max_icon_scroll_index() -> int:
    return int(ceil(_max_icon_scroll_offset() / maxf(_icon_step(), 1.0)))

func _max_icon_scroll_offset() -> float:
    var strip_width: float = icon_strip.custom_minimum_size.x
    if strip_width <= 0.0:
        strip_width = icon_strip.size.x
    var viewport_width: float = carousel_viewport.size.x
    if viewport_width <= 0.0:
        viewport_width = carousel_viewport.custom_minimum_size.x
    return maxf(0.0, strip_width - viewport_width)
