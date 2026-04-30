class_name GameRoot
extends Node3D

const TopBarView = preload("res://scripts/game/hud/top_bar.gd")
const PawnCollectionView = preload("res://scripts/game/pawns/pawn_collection.gd")

@onready var board_root: Node3D = get_node(^"BoardRoot")
@onready var pawn_root: Node3D = get_node(^"PawnRoot")
@onready var pawn_collection: PawnCollectionView = get_node(^"PawnRoot/pawns")
@onready var hud_root: CanvasLayer = get_node(^"HudRoot")
@onready var camera_rig: Node3D = get_node(^"CameraRig")

@onready var top_bar: TopBarView = get_node("HudRoot/SafeMargin/TopBar")

func _ready() -> void:
    assert(board_root)
    assert(pawn_root)
    assert(pawn_collection)
    assert(hud_root)
    assert(camera_rig)
    assert(top_bar)
    pawn_collection.bind_board_tiles(get_node(^"BoardRoot/tiles"))

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    if not is_node_ready():
        call_deferred("set_local_player_identity", icon_id, color_id)
        return
    top_bar.set_local_player_identity(icon_id, color_id)

func set_player_slots(slots: Array) -> void:
    if not is_node_ready():
        call_deferred("set_player_slots", slots.duplicate())
        return
    pawn_collection.sync_waiting_room_slots(slots)
