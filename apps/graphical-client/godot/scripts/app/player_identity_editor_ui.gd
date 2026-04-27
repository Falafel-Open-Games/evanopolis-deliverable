class_name PlayerIdentityEditorUI
extends MarginContainer

const PREVIEW_CARD_PATH: NodePath = ^"vbox/HBoxContainer/Preview Card/PlayerIdentityCardRoot"
const DISPLAY_NAME_LINE_EDIT_PATH: NodePath = ^"vbox/HBoxContainer/Name and Color/LineEdit"
const COLOR_PICKER_PATH: NodePath = ^"vbox/HBoxContainer/Name and Color/HBoxContainer"
const SAVE_BUTTON_PATH: NodePath = ^"vbox/HBoxContainer2/SaveButton"
const MAX_DISPLAY_NAME_LENGTH: int = 12

signal identity_draft_changed(display_name: String, color_id: int)
signal identity_save_requested(display_name: String, icon_id: int, color_id: int)

@onready var preview_card: PlayerIdentityCard = get_node(PREVIEW_CARD_PATH)
@onready var display_name_line_edit: LineEdit = get_node(DISPLAY_NAME_LINE_EDIT_PATH)
@onready var color_picker: IdentityColorPicker = get_node(COLOR_PICKER_PATH)
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

func _ready() -> void:
    assert(preview_card)
    assert(display_name_line_edit)
    assert(color_picker)
    assert(save_button)

    display_name_line_edit.max_length = MAX_DISPLAY_NAME_LENGTH
    display_name_line_edit.text_changed.connect(_on_display_name_text_changed)
    color_picker.color_selected.connect(_on_color_selected)
    save_button.pressed.connect(_on_save_button_pressed)
    _emit_identity_draft()
    _update_local_draft_state()
    _refresh_save_button_enabled()

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
    _selected_icon_id = _authoritative_icon_id
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
