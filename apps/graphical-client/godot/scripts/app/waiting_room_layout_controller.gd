extends Node

@export var collapsible_info_column: VBoxContainer
@export var identity_edit_button: Button
@export var middle_column_panel: Panel
@export var middle_column_close_button: Button

const TRANSITION_SECONDS: float = 0.24

var _expanded_info_width: float = 216.0
var _is_identity_edit_open: bool = false
var _is_transitioning: bool = false
var _transition_tween: Tween

func _ready() -> void:
    assert(collapsible_info_column)
    assert(identity_edit_button)
    assert(middle_column_panel)
    assert(middle_column_close_button)

    _expanded_info_width = collapsible_info_column.custom_minimum_size.x
    if _expanded_info_width <= 0.0:
        _expanded_info_width = 216.0

    identity_edit_button.pressed.connect(_on_identity_edit_button_pressed)
    middle_column_close_button.pressed.connect(_on_middle_column_close_button_pressed)

    middle_column_panel.visible = false
    middle_column_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
    middle_column_close_button.disabled = false

func open_identity_editor() -> void:
    if _is_transitioning or _is_identity_edit_open:
        return
    _start_transition(true)

func close_identity_editor() -> void:
    if _is_transitioning or not _is_identity_edit_open:
        return
    _start_transition(false)

func _on_identity_edit_button_pressed() -> void:
    open_identity_editor()

func _on_middle_column_close_button_pressed() -> void:
    close_identity_editor()

func _start_transition(should_open_identity_editor: bool) -> void:
    _is_transitioning = true
    identity_edit_button.disabled = true
    middle_column_close_button.disabled = true

    if _transition_tween != null and _transition_tween.is_running():
        _transition_tween.kill()
    _transition_tween = create_tween()
    _transition_tween.set_parallel(true)
    _transition_tween.set_trans(Tween.TRANS_CUBIC)
    _transition_tween.set_ease(Tween.EASE_IN_OUT)

    if should_open_identity_editor:
        middle_column_panel.visible = true
        _transition_tween.tween_method(_set_info_column_width, collapsible_info_column.custom_minimum_size.x, 0.0, TRANSITION_SECONDS)
        _transition_tween.tween_method(_set_middle_column_alpha, middle_column_panel.modulate.a, 1.0, TRANSITION_SECONDS)
    else:
        _transition_tween.tween_method(_set_info_column_width, collapsible_info_column.custom_minimum_size.x, _expanded_info_width, TRANSITION_SECONDS)
        _transition_tween.tween_method(_set_middle_column_alpha, middle_column_panel.modulate.a, 0.0, TRANSITION_SECONDS)

    _transition_tween.finished.connect(_on_transition_finished.bind(should_open_identity_editor))

func _on_transition_finished(open_identity_editor: bool) -> void:
    _is_identity_edit_open = open_identity_editor
    _is_transitioning = false

    identity_edit_button.disabled = _is_identity_edit_open
    middle_column_close_button.disabled = not _is_identity_edit_open

    if not _is_identity_edit_open:
        middle_column_panel.visible = false
        _set_middle_column_alpha(0.0)

func _set_info_column_width(width_value: float) -> void:
    var current_minimum_size: Vector2 = collapsible_info_column.custom_minimum_size
    collapsible_info_column.custom_minimum_size = Vector2(width_value, current_minimum_size.y)

func _set_middle_column_alpha(alpha_value: float) -> void:
    var current_modulate: Color = middle_column_panel.modulate
    middle_column_panel.modulate = Color(current_modulate.r, current_modulate.g, current_modulate.b, alpha_value)
