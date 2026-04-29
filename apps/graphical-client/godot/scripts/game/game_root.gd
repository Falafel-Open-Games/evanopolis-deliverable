class_name GameRoot
extends Node3D

const TopBarView = preload("res://scripts/game/hud/top_bar.gd")

@onready var board_root: Node3D = get_node(^"BoardRoot")
@onready var pawn_root: Node3D = get_node(^"PawnRoot")
@onready var hud_root: CanvasLayer = get_node(^"HudRoot")
@onready var camera_rig: Node3D = get_node(^"CameraRig")

@onready var top_bar: TopBarView = get_node("HudRoot/SafeMargin/TopBar")

func _ready() -> void:
    assert(board_root)
    assert(pawn_root)
    assert(hud_root)
    assert(camera_rig)
    assert(top_bar)

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    if not is_node_ready():
        call_deferred("set_local_player_identity", icon_id, color_id)
        return
    top_bar.set_local_player_identity(icon_id, color_id)
