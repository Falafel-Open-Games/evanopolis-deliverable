extends Control

const WaitingRoomState = preload("res://scripts/app/models/waiting_room_state.gd")
const WaitingRoomSlot = preload("res://scripts/app/models/waiting_room_slot.gd")
const WaitingRoomSeatScene = preload("res://scenes/app/waiting_room_seat.tscn")

const DEFAULT_IDENTITY_ICON_FRAME: int = 11
const DEFAULT_IDENTITY_COLOR_ID: int = 0

signal ready_requested
signal identity_save_requested(display_name: String, icon_id: int, color_id: int)

var _waiting_room_state: WaitingRoomState = null

@export var waiting_room_title_label: Label
@export var ready_button: Button
@export var info_body_label: Label
@export var identity_card: PlayerIdentityCard
@export var room_facts_label: Label
@export var seats_vbox: VBoxContainer
@export var roster_footer_label: Label
@export var identity_editor_ui: PlayerIdentityEditorUI

func _ready() -> void:
    assert(waiting_room_title_label)
    assert(info_body_label)
    assert(identity_card)
    assert(room_facts_label)
    assert(seats_vbox)
    assert(ready_button)
    assert(roster_footer_label)
    assert(identity_editor_ui)

    ready_button.pressed.connect(_on_ready_button_pressed)
    identity_editor_ui.identity_save_requested.connect(_on_identity_save_requested)
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

func set_identity_save_enabled(is_enabled: bool) -> void:
    identity_editor_ui.set_save_enabled(is_enabled)

func _on_ready_button_pressed() -> void:
    ready_requested.emit()

func _on_identity_save_requested(display_name: String, icon_id: int, color_id: int) -> void:
    identity_save_requested.emit(display_name, icon_id, color_id)

func _configure_static_copy() -> void:
    # info_body_label.text = ""
    pass

func _show_placeholder() -> void:
    waiting_room_title_label.text = "Preparing launch handoff"
    identity_card.set_identity("Player", "No player id yet", DEFAULT_IDENTITY_ICON_FRAME, DEFAULT_IDENTITY_COLOR_ID)
    identity_editor_ui.set_local_player_id("")
    identity_editor_ui.sync_authoritative_identity("", "", DEFAULT_IDENTITY_ICON_FRAME, DEFAULT_IDENTITY_COLOR_ID)
    identity_editor_ui.set_unavailable_color_ids([])
    room_facts_label.text = "Room facts"
    roster_footer_label.text = ""
    ready_button.text = "Ready"
    ready_button.disabled = true

func _render_waiting_room() -> void:
    if _waiting_room_state == null:
        _show_placeholder()
        return

    waiting_room_title_label.text = "Waiting for players"
    identity_card.set_identity(
        _waiting_room_state.local_display_name,
        _short_player_id(_waiting_room_state.local_player_id),
        _waiting_room_state.local_icon_id,
        _waiting_room_state.local_color_id
    )
    identity_editor_ui.sync_authoritative_identity(
        _waiting_room_state.local_player_id,
        _waiting_room_state.local_display_name,
        _waiting_room_state.local_icon_id,
        _waiting_room_state.local_color_id
    )
    identity_editor_ui.set_unavailable_color_ids(_used_color_ids_for_other_players())
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

func _used_color_ids_for_other_players() -> Array[int]:
    var used_color_ids: Array[int] = []
    if _waiting_room_state == null:
        return used_color_ids
    for slot_variant in _waiting_room_state.slots:
        var slot: WaitingRoomSlot = slot_variant
        if slot.is_local:
            continue
        if not slot.is_known_player:
            continue
        if slot.color_id < 0:
            continue
        if used_color_ids.has(slot.color_id):
            continue
        used_color_ids.append(slot.color_id)
    return used_color_ids
