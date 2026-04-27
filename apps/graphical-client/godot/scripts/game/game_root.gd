class_name GameRoot
extends Node3D

@onready var board_root: Node3D = get_node(^"BoardRoot")
@onready var pawn_root: Node3D = get_node(^"PawnRoot")
@onready var hud_root: CanvasLayer = get_node(^"HudRoot")
@onready var camera_rig: Node3D = get_node(^"CameraRig")

func _ready() -> void:
    assert(board_root)
    assert(pawn_root)
    assert(hud_root)
    assert(camera_rig)
