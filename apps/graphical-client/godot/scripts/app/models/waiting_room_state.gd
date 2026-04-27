extends RefCounted

const WaitingRoomSlot = preload("res://scripts/app/models/waiting_room_slot.gd")

var game_id: String
var room_capacity: int
var local_player_id: String
var local_player_index: int
var local_display_name: String
var local_icon_id: int
var local_color_id: int
var local_player_ready: bool
var ready_count: int
var slots: Array
var footer_note: String
var ready_request_pending: bool

func _init(
    initial_game_id: String,
    initial_room_capacity: int,
    initial_local_player_id: String,
    initial_local_player_index: int,
    initial_local_display_name: String,
    initial_local_icon_id: int,
    initial_local_color_id: int,
    initial_local_player_ready: bool,
    initial_ready_count: int,
    initial_slots: Array,
    initial_footer_note: String,
    initial_ready_request_pending: bool
) -> void:
    game_id = initial_game_id
    room_capacity = initial_room_capacity
    local_player_id = initial_local_player_id
    local_player_index = initial_local_player_index
    local_display_name = initial_local_display_name
    local_icon_id = initial_local_icon_id
    local_color_id = initial_local_color_id
    local_player_ready = initial_local_player_ready
    ready_count = initial_ready_count
    slots = initial_slots
    footer_note = initial_footer_note
    ready_request_pending = initial_ready_request_pending

func clone():
    var cloned_slots: Array = []
    for slot_variant in slots:
        var slot: WaitingRoomSlot = slot_variant
        cloned_slots.append(slot.clone())
    return get_script().new(
        game_id,
        room_capacity,
        local_player_id,
        local_player_index,
        local_display_name,
        local_icon_id,
        local_color_id,
        local_player_ready,
        ready_count,
        cloned_slots,
        footer_note,
        ready_request_pending
    )
