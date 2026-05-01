class_name GameRoot
extends Node3D

const TopBarView = preload("res://scripts/game/hud/top_bar.gd")
const PlayersListPanelView = preload("res://scripts/game/hud/players_list_panel.gd")
const PawnCollectionView = preload("res://scripts/game/pawns/pawn_collection.gd")

@onready var board_root: Node3D = get_node(^"BoardRoot")
@onready var pawn_root: Node3D = get_node(^"PawnRoot")
@onready var pawn_collection: PawnCollectionView = get_node(^"PawnRoot/pawns")
@onready var hud_root: CanvasLayer = get_node(^"HudRoot")
@onready var camera_rig: Node3D = get_node(^"CameraRig")

@onready var top_bar: TopBarView = get_node("HudRoot/SafeMargin/TopBar")
@onready var players_list_panel: PlayersListPanelView = get_node(^"HudRoot/SafeMargin/PlayersList")

func _ready() -> void:
    assert(board_root)
    assert(pawn_root)
    assert(pawn_collection)
    assert(hud_root)
    assert(camera_rig)
    assert(top_bar)
    assert(players_list_panel)
    pawn_collection.bind_board_tiles(get_node(^"BoardRoot/tiles"))

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    if not is_node_ready():
        call_deferred("set_local_player_identity", icon_id, color_id)
        return
    top_bar.set_local_player_identity(icon_id, color_id)

func set_turn_info(turn_number: int, player_name: String, is_local_turn: bool) -> void:
    if not is_node_ready():
        call_deferred("set_turn_info", turn_number, player_name, is_local_turn)
        return
    top_bar.set_turn_info(turn_number, player_name, is_local_turn)

func set_player_slots(slots: Array) -> void:
    if not is_node_ready():
        call_deferred("set_player_slots", slots.duplicate())
        return
    pawn_collection.sync_waiting_room_slots(slots)

func set_player_states(player_states: Array) -> void:
    if not is_node_ready():
        call_deferred("set_player_states", player_states.duplicate())
        return
    players_list_panel.set_player_states(player_states)
