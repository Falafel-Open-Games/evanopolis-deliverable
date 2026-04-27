extends Control

const StatusCardState = preload("res://scripts/app/models/status_view_state.gd")
const WaitingRoomState = preload("res://scripts/app/models/waiting_room_state.gd")

@export var boot_node: AppBoot
@export var session_node: SessionCheck

var _boot_state: StatusCardState
var _session_state: StatusCardState
var _waiting_room_state: WaitingRoomState = null

@onready var waiting_room_view: Control = $WaitingRoomMount/WaitingRoomRoot
@onready var modal_shade: ColorRect = $ModalShade
@onready var modal_panel: ColorRect = $ModalCenter/ModalPanel
@onready var status_label: Label = $ModalCenter/ModalPanel/ModalMargin/ModalVBox/ModalStatusLabel
@onready var detail_label: Label = $ModalCenter/ModalPanel/ModalMargin/ModalVBox/ModalDetailLabel
@onready var note_label: Label = $ModalCenter/ModalPanel/ModalMargin/ModalVBox/ModalNoteLabel

func _ready() -> void:
    assert(waiting_room_view)
    assert(modal_shade)
    assert(modal_panel)
    assert(status_label)
    assert(detail_label)
    assert(note_label)
    assert(boot_node)
    assert(boot_node.has_signal("boot_state_changed"))
    assert(boot_node.has_method("get_boot_state"))

    assert(session_node)
    assert(session_node.has_signal("session_state_changed"))
    assert(session_node.has_signal("waiting_room_state_changed"))
    assert(session_node.has_method("get_session_state"))
    assert(session_node.has_method("get_waiting_room_state"))
    assert(session_node.has_method("is_waiting_for_launch"))
    assert(session_node.has_method("is_waiting_room_active"))
    assert(session_node.has_method("has_waiting_room_state"))
    assert(session_node.has_method("can_request_player_ready"))
    assert(session_node.has_method("request_player_ready"))
    assert(session_node.has_method("can_request_player_identity"))
    assert(session_node.has_method("request_player_identity"))

    waiting_room_view.connect("ready_requested", Callable(self, "_on_ready_button_pressed"))
    waiting_room_view.connect("identity_save_requested", Callable(self, "_on_identity_save_requested"))

    boot_node.connect("boot_state_changed", Callable(self, "_on_boot_state_changed"))
    session_node.connect("session_state_changed", Callable(self, "_on_session_state_changed"))
    session_node.connect("waiting_room_state_changed", Callable(self, "_on_waiting_room_state_changed"))

    _boot_state = boot_node.call("get_boot_state")
    _session_state = session_node.call("get_session_state")
    if session_node.call("has_waiting_room_state"):
        _waiting_room_state = session_node.call("get_waiting_room_state")

    _render_scene()

func _on_boot_state_changed(state: StatusCardState) -> void:
    _boot_state = state
    _render_scene()

func _on_session_state_changed(state: StatusCardState) -> void:
    _session_state = state
    _render_scene()

func _on_waiting_room_state_changed(state: WaitingRoomState) -> void:
    _waiting_room_state = state
    _render_scene()

func _on_ready_button_pressed() -> void:
    session_node.call("request_player_ready")

func _on_identity_save_requested(display_name: String, icon_id: int, color_id: int) -> void:
    session_node.call("request_player_identity", display_name, icon_id, color_id)

func _render_scene() -> void:
    var status_state: StatusCardState = _boot_state
    if not session_node.call("is_waiting_for_launch"):
        status_state = _session_state

    var waiting_room_active: bool = session_node.call("is_waiting_room_active")
    _render_modal(waiting_room_active, status_state)
    _render_waiting_room(waiting_room_active)

func _render_modal(waiting_room_active: bool, status_state: StatusCardState) -> void:
    modal_shade.visible = not waiting_room_active
    modal_panel.visible = not waiting_room_active
    status_label.text = status_state.title
    detail_label.text = status_state.detail
    note_label.text = status_state.note

func _render_waiting_room(waiting_room_active: bool) -> void:
    var has_waiting_room_state: bool = waiting_room_active and _waiting_room_state != null
    waiting_room_view.call("set_waiting_room_active", has_waiting_room_state)

    if not has_waiting_room_state:
        if session_node.call("is_waiting_for_launch"):
            waiting_room_view.call("set_title_text", "Preparing launch handoff")
        else:
            waiting_room_view.call("set_title_text", _session_state.title)
        return

    waiting_room_view.call("set_waiting_room_state", _waiting_room_state)
    waiting_room_view.call("set_ready_enabled", session_node.call("can_request_player_ready"))
    waiting_room_view.call("set_identity_save_enabled", session_node.call("can_request_player_identity"))
