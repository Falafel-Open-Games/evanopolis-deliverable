extends Control

const StatusCardState = preload("res://scripts/app/models/status_view_state.gd")

@export var boot_node_path: NodePath = NodePath("/root/HeadlessRpc/AppBoot")
@export var session_node_path: NodePath = NodePath("/root/HeadlessRpc")

@onready var status_label: Label = $SessionCenterContainer/SessionPanel/SessionMarginContainer/SessionVBox/SessionStatusLabel
@onready var detail_label: Label = $SessionCenterContainer/SessionPanel/SessionMarginContainer/SessionVBox/SessionDetailLabel
@onready var note_label: Label = $SessionCenterContainer/SessionPanel/SessionMarginContainer/SessionVBox/SessionNoteLabel

var _boot_node: AppBoot = null
var _session_node: Node = null
var _boot_state: StatusCardState
var _session_state: StatusCardState
var _session_has_started: bool = false

func _ready() -> void:
    assert(status_label)
    assert(detail_label)
    assert(note_label)

    _boot_node = get_node(boot_node_path)
    assert(_boot_node)
    assert(_boot_node.has_signal("boot_state_changed"))
    assert(_boot_node.has_method("get_boot_state"))

    _session_node = get_node(session_node_path)
    assert(_session_node)
    assert(_session_node.has_signal("session_state_changed"))
    assert(_session_node.has_method("get_session_state"))
    assert(_session_node.has_method("is_waiting_for_launch"))

    _boot_node.connect("boot_state_changed", Callable(self, "_on_boot_state_changed"))
    _session_node.connect("session_state_changed", Callable(self, "_on_session_state_changed"))
    _boot_state = _boot_node.call("get_boot_state")
    _session_state = _session_node.call("get_session_state")
    _session_has_started = not _session_node.call("is_waiting_for_launch")
    _render_active_state()

func _on_boot_state_changed(state: StatusCardState) -> void:
    _boot_state = state
    _render_active_state()

func _on_session_state_changed(state: StatusCardState) -> void:
    _session_state = state
    _session_has_started = not _session_node.call("is_waiting_for_launch")
    _render_active_state()

func _render_active_state() -> void:
    var state: StatusCardState = _boot_state
    if _session_has_started:
        state = _session_state

    status_label.text = state.title
    detail_label.text = state.detail
    note_label.text = state.note
