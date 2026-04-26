extends Control

const WaitingRoomState = preload("res://scripts/app/models/waiting_room_state.gd")
const WaitingRoomSlot = preload("res://scripts/app/models/waiting_room_slot.gd")
const WaitingRoomSeatScene = preload("res://scenes/app/waiting_room_seat.tscn")

const SECONDARY_TEXT_COLOR: Color = Color(0.823529, 0.831373, 0.756863, 1.0)

signal ready_requested

var _waiting_room_state: WaitingRoomState = null

@export var waiting_room_title_label: Label
@export var ready_button: Button
@export var info_body_label: Label
@export var identity_seat_label: Label
@export var identity_player_label: Label
@export var identity_note_label: Label
@export var room_facts_label: Label
@export var seats_vbox: VBoxContainer
@export var roster_footer_label: Label

func _ready() -> void:
    assert(waiting_room_title_label)
    assert(info_body_label)
    assert(identity_seat_label)
    assert(identity_player_label)
    assert(identity_note_label)
    assert(room_facts_label)
    assert(seats_vbox)
    assert(ready_button)
    assert(roster_footer_label)

    ready_button.pressed.connect(_on_ready_button_pressed)
    _configure_static_copy()
    _show_placeholder()

func set_waiting_room_state(state: WaitingRoomState) -> void:
    _waiting_room_state = state
    _render_waiting_room()

func set_waiting_room_active(active: bool) -> void:
    visible = active

func set_title_text(title_text: String) -> void:
    waiting_room_title_label.text = title_text

func set_ready_enabled(is_enabled: bool) -> void:
    ready_button.disabled = not is_enabled

func _on_ready_button_pressed() -> void:
    ready_requested.emit()

func _configure_static_copy() -> void:
    # info_body_label.text = ""
    pass

func _show_placeholder() -> void:
    waiting_room_title_label.text = "Preparing launch handoff"
    identity_seat_label.text = "Seat"
    identity_player_label.text = "Player"
    identity_note_label.text = "Short name, icon, and color customization will land after the server snapshot carries waiting-room identity metadata."
    room_facts_label.text = "Room facts"
    roster_footer_label.text = ""
    ready_button.text = "Ready"
    ready_button.disabled = true

func _render_waiting_room() -> void:
    if _waiting_room_state == null:
        _show_placeholder()
        return

    waiting_room_title_label.text = "Waiting for players"
    identity_seat_label.text = "Seat %d of %d" % [_waiting_room_state.local_player_index + 1, _waiting_room_state.room_capacity]
    identity_player_label.text = _short_player_id(_waiting_room_state.local_player_id)
    identity_note_label.text = "Short name, icon, and color customization will land after the server snapshot carries waiting-room identity metadata."
    room_facts_label.text = "Room %s  |  %d/%d ready" % [
        _waiting_room_state.game_id,
        _waiting_room_state.ready_count,
        _waiting_room_state.room_capacity,
    ]
    roster_footer_label.text = _waiting_room_state.footer_note

    if _waiting_room_state.local_player_ready:
        ready_button.text = "Ready Locked In"
    elif _waiting_room_state.ready_request_pending:
        ready_button.text = "Sending Ready…"
    else:
        ready_button.text = "Ready"

    _rebuild_seats()

func _rebuild_seats() -> void:
    for child in seats_vbox.get_children():
        seats_vbox.remove_child(child)
        child.queue_free()

    for slot_variant in _waiting_room_state.slots:
        var slot: WaitingRoomSlot = slot_variant
        var seat_card: Control = WaitingRoomSeatScene.instantiate()
        assert(seat_card.has_method("set_slot"))
        seat_card.call("set_slot", slot)
        seats_vbox.add_child(seat_card)

func _short_player_id(player_id: String) -> String:
    if player_id.is_empty():
        return "No player id yet"
    if player_id.length() <= 18:
        return player_id
    return "%s...%s" % [player_id.substr(0, 8), player_id.substr(player_id.length() - 6, 6)]
