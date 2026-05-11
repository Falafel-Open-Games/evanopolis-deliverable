class_name Pawn
extends Node3D

const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")
const STEP_ARC_HEIGHT: float = 0.4
const STEP_DURATION_SECONDS: float = 0.3
const STEP_PAUSE_SECONDS: float = 0.1

var player_index: int = -1
var color_id: int = PlayerIdentityCardView.DEFAULT_COLOR_ID

var _mesh_instance: MeshInstance3D = null
var _material_templates_by_color_id: Array[Material] = []
var _material_instances_by_color_id: Array[Material] = []
var _fallback_material_instance: StandardMaterial3D = null
var _movement_tween: Tween = null
var _movement_target_transform: Transform3D = Transform3D.IDENTITY
var _has_movement_target: bool = false

func configure(initial_player_index: int, initial_color_id: int, initial_transform: Transform3D) -> void:
    set_player_index(initial_player_index)
    set_color_id(initial_color_id)
    set_board_transform(initial_transform)

func set_mesh_template(template_mesh: Mesh, template_materials_by_color_id: Array[Material]) -> void:
    assert(template_mesh != null)
    assert(template_materials_by_color_id.size() == PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size())
    if _mesh_instance == null:
        _mesh_instance = MeshInstance3D.new()
        _mesh_instance.name = "Mesh"
        add_child(_mesh_instance)
    _mesh_instance.mesh = template_mesh
    _material_templates_by_color_id = template_materials_by_color_id.duplicate()
    _material_instances_by_color_id.clear()
    _material_instances_by_color_id.resize(_material_templates_by_color_id.size())
    _fallback_material_instance = null
    _apply_color()

func set_player_index(value: int) -> void:
    player_index = value

func set_color_id(value: int) -> void:
    color_id = _resolved_color_id(value)
    _apply_color()

func set_board_position(board_position: Vector3, board_basis: Basis = Basis.IDENTITY) -> void:
    set_board_transform(Transform3D(board_basis, board_position))

func set_board_transform(board_transform: Transform3D) -> void:
    stop_movement_animation()
    transform = board_transform

func animate_board_transforms(step_transforms: Array[Transform3D]) -> void:
    if step_transforms.is_empty():
        return
    stop_movement_animation()
    if step_transforms.size() == 1:
        transform = step_transforms[0]
        return

    _movement_target_transform = step_transforms[step_transforms.size() - 1]
    _has_movement_target = true
    _movement_tween = create_tween()
    _movement_tween.set_parallel(false)
    for step_index in range(step_transforms.size()):
        var from_transform: Transform3D = transform if step_index == 0 else step_transforms[step_index - 1]
        var to_transform: Transform3D = step_transforms[step_index]
        _movement_tween.tween_method(
            _set_arc_transform.bind(from_transform, to_transform),
            0.0,
            1.0,
            STEP_DURATION_SECONDS
        )
        if STEP_PAUSE_SECONDS > 0.0 and step_index < step_transforms.size() - 1:
            _movement_tween.tween_interval(STEP_PAUSE_SECONDS)
    _movement_tween.finished.connect(_on_movement_tween_finished)

func stop_movement_animation() -> void:
    if _movement_tween == null:
        _has_movement_target = false
        return
    if _movement_tween.is_running():
        _movement_tween.kill()
    _movement_tween = null
    _has_movement_target = false

func is_animating_to_transform(board_transform: Transform3D) -> bool:
    if _movement_tween == null or not _has_movement_target:
        return false
    return _movement_target_transform.is_equal_approx(board_transform)

func _set_arc_transform(progress: float, from_transform: Transform3D, to_transform: Transform3D) -> void:
    var clamped_progress: float = clampf(progress, 0.0, 1.0)
    var next_origin: Vector3 = from_transform.origin.lerp(to_transform.origin, clamped_progress)
    var arc_offset: float = sin(clamped_progress * PI) * STEP_ARC_HEIGHT
    next_origin.y += arc_offset
    transform = Transform3D(from_transform.basis.slerp(to_transform.basis, clamped_progress), next_origin)

func _on_movement_tween_finished() -> void:
    _movement_tween = null
    _has_movement_target = false

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
    if _mesh_instance == null:
        return
    var resolved_id: int = _resolved_color_id(color_id)
    var material_instance: Material = _material_instance_for_color_id(resolved_id)
    _mesh_instance.material_override = material_instance

func _material_instance_for_color_id(resolved_id: int) -> Material:
    var cached_material: Material = _material_instances_by_color_id[resolved_id]
    if cached_material != null:
        return cached_material

    var template_material: Material = _material_templates_by_color_id[resolved_id]
    if template_material != null:
        var duplicated_resource: Resource = template_material.duplicate()
        var duplicated_material: Material = duplicated_resource as Material
        if duplicated_material != null:
            _material_instances_by_color_id[resolved_id] = duplicated_material
            return duplicated_material

    if _fallback_material_instance == null:
        _fallback_material_instance = _duplicate_template_material(null)
    _fallback_material_instance.albedo_color = _color_from_id(resolved_id)
    _material_instances_by_color_id[resolved_id] = _fallback_material_instance
    return _fallback_material_instance

func _color_from_id(requested_color_id: int) -> Color:
    return PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS[_resolved_color_id(requested_color_id)]

func _resolved_color_id(requested_color_id: int) -> int:
    if (
        requested_color_id < 0
        or requested_color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size()
    ):
        return PlayerIdentityCardView.DEFAULT_COLOR_ID
    return requested_color_id
