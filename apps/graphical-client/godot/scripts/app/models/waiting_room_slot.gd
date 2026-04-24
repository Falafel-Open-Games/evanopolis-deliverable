extends RefCounted

var player_index: int
var display_name: String
var status_text: String
var is_local: bool
var is_ready: bool
var is_known_player: bool

func _init(
    initial_player_index: int,
    initial_display_name: String,
    initial_status_text: String,
    initial_is_local: bool,
    initial_is_ready: bool,
    initial_is_known_player: bool
) -> void:
    player_index = initial_player_index
    display_name = initial_display_name
    status_text = initial_status_text
    is_local = initial_is_local
    is_ready = initial_is_ready
    is_known_player = initial_is_known_player

func clone():
    return get_script().new(
        player_index,
        display_name,
        status_text,
        is_local,
        is_ready,
        is_known_player
    )
