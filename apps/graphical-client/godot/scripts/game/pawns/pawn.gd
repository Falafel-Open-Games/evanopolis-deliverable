class_name Pawn
extends Node3D

const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")

var player_index: int = -1
var color_id: int = PlayerIdentityCardView.DEFAULT_COLOR_ID

var _mesh_instance: MeshInstance3D = null
var _material_instance: StandardMaterial3D = null

func configure(initial_player_index: int, initial_color_id: int, initial_transform: Transform3D) -> void:
    set_player_index(initial_player_index)
    set_color_id(initial_color_id)
    set_board_transform(initial_transform)

func set_mesh_template(template_mesh: Mesh, template_material: Material) -> void:
    assert(template_mesh != null)
    if _mesh_instance == null:
        _mesh_instance = MeshInstance3D.new()
        _mesh_instance.name = "Mesh"
        add_child(_mesh_instance)
    _mesh_instance.mesh = template_mesh
    _material_instance = _duplicate_template_material(template_material)
    _mesh_instance.material_override = _material_instance
    _apply_color()

func set_player_index(value: int) -> void:
    player_index = value

func set_color_id(value: int) -> void:
    color_id = _resolved_color_id(value)
    _apply_color()

func set_board_position(board_position: Vector3, board_basis: Basis = Basis.IDENTITY) -> void:
    set_board_transform(Transform3D(board_basis, board_position))

func set_board_transform(board_transform: Transform3D) -> void:
    transform = board_transform

func _duplicate_template_material(template_material: Material) -> StandardMaterial3D:
    var duplicated_material: StandardMaterial3D = null
    var typed_template_material: StandardMaterial3D = template_material as StandardMaterial3D
    if typed_template_material != null:
        var duplicated_resource: Resource = typed_template_material.duplicate()
        duplicated_material = duplicated_resource as StandardMaterial3D
    if duplicated_material == null:
        duplicated_material = StandardMaterial3D.new()
        duplicated_material.cull_mode = BaseMaterial3D.CULL_DISABLED
        duplicated_material.roughness = 0.5
    return duplicated_material

func _apply_color() -> void:
    if _material_instance == null:
        return
    _material_instance.albedo_color = _color_from_id(color_id)

func _color_from_id(requested_color_id: int) -> Color:
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[_resolved_color_id(requested_color_id)]

func _resolved_color_id(requested_color_id: int) -> int:
    if (
        requested_color_id < 0
        or requested_color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size()
    ):
        return PlayerIdentityCardView.DEFAULT_COLOR_ID
    return requested_color_id
