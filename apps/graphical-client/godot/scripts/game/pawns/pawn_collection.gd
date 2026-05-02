class_name PawnCollection
extends Node3D

const PawnView = preload("res://scripts/game/pawns/pawn.gd")
const PlayerIdentityCardView = preload("res://scripts/app/player_identity_card.gd")
const ANCHOR_EPSILON: float = 0.001
const VISUAL_RING_START_TILES_BY_COLOR_ID: Array[int] = [12, 15, 0, 3, 6, 9]

@onready var initial_positions: Node3D = get_node(^"InitialPositions")
@onready var pawn_instances: Node3D = get_node(^"PawnInstances")

var _pawns_by_player_index: Dictionary = { }
var _authoritative_tile_positions_by_player_index: Dictionary = { }
var _spawn_transforms_by_color_id: Array[Transform3D] = []
var _legacy_color_slot_transforms: Array[Transform3D] = []
var _tile_transforms_by_index: Array[Transform3D] = []
var _template_mesh: Mesh = null
var _template_materials_by_color_id: Array[Material] = []

func _ready() -> void:
    assert(initial_positions)
    assert(pawn_instances)
    _capture_template_and_spawn_positions()

func bind_board_tiles(board_tiles_root: Node3D) -> void:
    assert(board_tiles_root != null)
    _tile_transforms_by_index = _resolve_tile_transforms_by_index(board_tiles_root)
    _spawn_transforms_by_color_id = _resolve_start_transforms_from_tiles(board_tiles_root)

func sync_waiting_room_slots(slots: Array) -> void:
    assert(is_node_ready())
    var active_player_indices: Dictionary = { }
    for slot in slots:
        if slot == null:
            continue
        if not bool(slot.is_known_player):
            continue
        var player_index: int = int(slot.player_index)
        var color_id: int = int(slot.color_id)
        var pawn: Pawn = ensure_pawn(player_index, color_id)
        pawn.configure(player_index, color_id, _spawn_transform_for_player(player_index, color_id))
        active_player_indices[player_index] = true

    var player_indices: Array = _pawns_by_player_index.keys()
    for player_index_variant in player_indices:
        var player_index: int = int(player_index_variant)
        if active_player_indices.has(player_index):
            continue
        remove_pawn(player_index)

func sync_gameplay_player_states(player_states: Array) -> void:
    assert(is_node_ready())
    var active_player_indices: Dictionary = { }
    for state_variant in player_states:
        if state_variant == null:
            continue
        var player_index: int = int(state_variant.player_index)
        if player_index < 0:
            continue
        var color_id: int = int(state_variant.color_id)
        var pawn: Pawn = ensure_pawn(player_index, color_id)
        pawn.set_color_id(color_id)
        _apply_authoritative_tile_position(player_index)
        active_player_indices[player_index] = true

    var player_indices: Array = _pawns_by_player_index.keys()
    for player_index_variant in player_indices:
        var player_index: int = int(player_index_variant)
        if active_player_indices.has(player_index):
            continue
        remove_pawn(player_index)

func ensure_pawn(player_index: int, initial_color_id: int = PlayerIdentityCardView.DEFAULT_COLOR_ID) -> Pawn:
    assert(is_node_ready())
    if _pawns_by_player_index.has(player_index):
        return _pawns_by_player_index[player_index] as Pawn

    var pawn: Pawn = PawnView.new()
    pawn.name = "Pawn%d" % player_index
    pawn.set_mesh_template(_template_mesh, _template_materials_by_color_id)
    pawn_instances.add_child(pawn)
    _pawns_by_player_index[player_index] = pawn
    pawn.configure(player_index, initial_color_id, _spawn_transform_for_player(player_index, initial_color_id))
    return pawn

func set_pawn_color(player_index: int, color_id: int) -> void:
    var pawn: Pawn = ensure_pawn(player_index, color_id)
    pawn.set_color_id(color_id)

func set_pawn_position(player_index: int, board_position: Vector3, board_basis: Basis = Basis.IDENTITY) -> void:
    var pawn: Pawn = ensure_pawn(player_index)
    pawn.set_board_position(board_position, board_basis)

func set_pawn_transform(player_index: int, board_transform: Transform3D) -> void:
    var pawn: Pawn = ensure_pawn(player_index)
    pawn.set_board_transform(board_transform)

func set_pawn_tile_index(player_index: int, tile_index: int) -> void:
    assert(tile_index >= 0)
    var tile_transform: Transform3D = get_tile_transform(tile_index)
    set_pawn_transform(player_index, tile_transform)

func sync_authoritative_tile_positions(tile_positions_by_player_index: Dictionary) -> void:
    _authoritative_tile_positions_by_player_index = tile_positions_by_player_index.duplicate(true)
    for player_index_variant in tile_positions_by_player_index.keys():
        var player_index: int = int(player_index_variant)
        var tile_index: int = int(tile_positions_by_player_index.get(player_index_variant, -1))
        if tile_index < 0:
            continue
        set_pawn_tile_index(player_index, tile_index)

func get_tile_transform(tile_index: int) -> Transform3D:
    assert(_tile_transforms_by_index.size() > 0)
    if tile_index >= _tile_transforms_by_index.size():
        return _tile_transforms_by_index[tile_index % _tile_transforms_by_index.size()]
    return _tile_transforms_by_index[tile_index]

func get_default_spawn_transform(color_id: int) -> Transform3D:
    assert(_spawn_transforms_by_color_id.size() > 0)
    return _spawn_transforms_by_color_id[_resolved_color_id(color_id)]

func _spawn_transform_for_player(player_index: int, color_id: int) -> Transform3D:
    var tile_index: int = int(_authoritative_tile_positions_by_player_index.get(player_index, -1))
    if tile_index >= 0 and _tile_transforms_by_index.size() > 0:
        return get_tile_transform(tile_index)
    return get_default_spawn_transform(color_id)

func _apply_authoritative_tile_position(player_index: int) -> void:
    var tile_index: int = int(_authoritative_tile_positions_by_player_index.get(player_index, -1))
    if tile_index < 0:
        return
    set_pawn_tile_index(player_index, tile_index)

func remove_pawn(player_index: int) -> void:
    var pawn: Pawn = _pawns_by_player_index.get(player_index, null) as Pawn
    if pawn == null:
        return
    _pawns_by_player_index.erase(player_index)
    pawn.queue_free()

func clear_pawns() -> void:
    for pawn_variant in _pawns_by_player_index.values():
        var pawn: Pawn = pawn_variant as Pawn
        if pawn == null:
            continue
        pawn.queue_free()
    _pawns_by_player_index.clear()

func debug_print_pawn_layout(context: String = "") -> void:
    if not _should_print_debug_gameplay_state():
        return
    var pawn_summaries: Array[String] = []
    var player_indices: Array = _pawns_by_player_index.keys()
    player_indices.sort()
    for player_index_variant in player_indices:
        var player_index: int = int(player_index_variant)
        var pawn: Pawn = _pawns_by_player_index[player_index] as Pawn
        if pawn == null:
            continue
        pawn_summaries.append(
            "p%d color=%d origin=(%.2f, %.2f, %.2f)" % [
                player_index,
                pawn.color_id,
                pawn.transform.origin.x,
                pawn.transform.origin.y,
                pawn.transform.origin.z,
            ]
        )
    print_debug("[pawn-layout%s] %s" % [
        "" if context.is_empty() else ":%s" % context,
        ", ".join(pawn_summaries),
    ])


func _should_print_debug_gameplay_state() -> bool:
    return OS.has_environment("EVANOPOLIS_DEBUG_GAMEPLAY")

func _capture_template_and_spawn_positions() -> void:
    var markers: Array[MeshInstance3D] = []
    _collect_marker_meshes(initial_positions, markers)
    assert(markers.size() == PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size())
    # Imported child order is not stable. The marker suffix is the only index
    # source we trust here.
    markers.sort_custom(func(first: MeshInstance3D, second: MeshInstance3D) -> bool:
        return _marker_export_index(first) < _marker_export_index(second)
    )

    _spawn_transforms_by_color_id.clear()
    _legacy_color_slot_transforms.clear()
    _template_materials_by_color_id.clear()
    _spawn_transforms_by_color_id.resize(PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size())
    _legacy_color_slot_transforms.resize(PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size())
    _template_materials_by_color_id.resize(PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size())
    for marker in markers:
        var color_id: int = _marker_export_index(marker)
        assert(color_id >= 0 and color_id < PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size())
        _spawn_transforms_by_color_id[color_id] = marker.transform
        _legacy_color_slot_transforms[color_id] = marker.transform
        _template_materials_by_color_id[color_id] = _marker_material(marker)

    var template_marker: MeshInstance3D = markers[0]
    _template_mesh = template_marker.mesh
    assert(_template_mesh != null)
    initial_positions.visible = false

func _collect_marker_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
    for child in node.get_children():
        var mesh_instance: MeshInstance3D = child as MeshInstance3D
        if mesh_instance != null:
            result.append(mesh_instance)
            continue
        _collect_marker_meshes(child, result)

func _marker_export_index(marker: MeshInstance3D) -> int:
    var marker_name: String = String(marker.name)
    var marker_name_parts: PackedStringArray = marker_name.split("_")
    assert(marker_name_parts.size() > 1)
    var suffix_text: String = marker_name_parts[marker_name_parts.size() - 1]
    var export_index: int = int(suffix_text)
    assert(export_index >= 0)
    return export_index

func _marker_material(marker: MeshInstance3D) -> Material:
    var active_material: Material = marker.get_active_material(0)
    if active_material != null:
        return active_material
    var marker_mesh: Mesh = marker.mesh
    if marker_mesh != null and marker_mesh.get_surface_count() > 0:
        return marker_mesh.surface_get_material(0)
    return null

func _resolved_color_id(requested_color_id: int) -> int:
    if (
        requested_color_id < 0
        or requested_color_id >= PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size()
    ):
        return PlayerIdentityCardView.DEFAULT_COLOR_ID
    return requested_color_id

func _resolve_start_transforms_from_tiles(board_tiles_root: Node3D) -> Array[Transform3D]:
    if _tile_transforms_by_index.is_empty():
        _tile_transforms_by_index = _resolve_tile_transforms_by_index(board_tiles_root)
    var start_transforms: Array[Transform3D] = []
    start_transforms.resize(PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size())
    for color_id in range(PlayerIdentityCardView.PLAYER_REPRESENTATION_COLORS.size()):
        var tile_index: int = _starting_tile_for_color(color_id)
        start_transforms[color_id] = get_tile_transform(tile_index)
    return start_transforms

func _starting_tile_for_color(color_id: int) -> int:
    assert(_tile_transforms_by_index.size() > 0)
    return VISUAL_RING_START_TILES_BY_COLOR_ID[_resolved_color_id(color_id)]

func _resolve_tile_transforms_by_index(board_tiles_root: Node3D) -> Array[Transform3D]:
    var ordered_tiles: Array[Dictionary] = _ordered_tile_entries(board_tiles_root)
    var transforms: Array[Transform3D] = []
    var max_tile_index: int = -1
    for tile_entry in ordered_tiles:
        max_tile_index = max(max_tile_index, int(tile_entry.get("tile_index", -1)))
    assert(max_tile_index >= 0)
    transforms.resize(max_tile_index + 1)
    for tile_entry in ordered_tiles:
        var tile_index: int = int(tile_entry.get("tile_index", -1))
        assert(tile_index >= 0 and tile_index < transforms.size())
        transforms[tile_index] = tile_entry.get("transform", Transform3D.IDENTITY)
    return transforms

func _ordered_tile_entries(board_tiles_root: Node3D) -> Array[Dictionary]:
    var tile_entries: Array[Dictionary] = []
    for child in board_tiles_root.get_children():
        if not String(child.name).begins_with("TileInstance"):
            continue
        var tile_instance: Node3D = child as Node3D
        assert(tile_instance != null)
        tile_entries.append(_build_tile_entry(tile_instance))

    tile_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("tile_index", 0)) < int(b.get("tile_index", 0))
    )

    # Tile indices come from the exported node names, never from child order.
    return tile_entries

func _build_tile_entry(tile_instance: Node3D) -> Dictionary:
    var tile_anchor: Node3D = _find_tile_anchor(tile_instance)
    var tile_mesh: MeshInstance3D = _find_tile_mesh(tile_instance)
    assert(tile_mesh != null)

    var tile_point_global: Vector3 = _tile_point_global_position(tile_instance, tile_anchor, tile_mesh)
    var pawn_origin_global: Vector3 = tile_point_global
    var pawn_transform_global: Transform3D = Transform3D(tile_instance.global_basis, pawn_origin_global)
    var pawn_transform_local: Transform3D = global_transform.affine_inverse() * pawn_transform_global
    var tile_point_local: Vector3 = to_local(tile_point_global)
    var angle: float = atan2(tile_point_local.z, tile_point_local.x)

    return {
        "tile_name": String(tile_instance.name),
        "tile_index": _tile_export_index(tile_instance),
        "transform": pawn_transform_local,
        "position": pawn_transform_local.origin,
        "angle": angle,
    }

func _tile_point_global_position(
    _tile_instance: Node3D,
    tile_anchor: Node3D,
    tile_mesh: MeshInstance3D
) -> Vector3:
    if tile_anchor != null and tile_anchor.transform.origin.length() > ANCHOR_EPSILON:
        return tile_anchor.global_transform.origin
    var mesh_top_center_local: Vector3 = _mesh_top_center_local(tile_mesh)
    return tile_mesh.global_transform * mesh_top_center_local

func _mesh_top_center_local(tile_mesh: MeshInstance3D) -> Vector3:
    var mesh_aabb: AABB = tile_mesh.get_aabb()
    return Vector3(
        mesh_aabb.get_center().x,
        mesh_aabb.position.y + mesh_aabb.size.y,
        mesh_aabb.get_center().z
    )

func _find_tile_anchor(tile_instance: Node3D) -> Node3D:
    for child in tile_instance.get_children():
        var node3d: Node3D = child as Node3D
        if node3d == null:
            continue
        if String(node3d.name).contains("CentralAnchor"):
            return node3d
    return null

func _find_tile_mesh(tile_instance: Node3D) -> MeshInstance3D:
    for child in tile_instance.get_children():
        var mesh_instance: MeshInstance3D = child as MeshInstance3D
        if mesh_instance != null:
            return mesh_instance
    return null

func _tile_export_index(tile_instance: Node3D) -> int:
    var tile_name: String = String(tile_instance.name)
    var tile_name_parts: PackedStringArray = tile_name.split("_")
    assert(tile_name_parts.size() > 1)
    var suffix_text: String = tile_name_parts[tile_name_parts.size() - 1]
    var export_index: int = int(suffix_text)
    assert(export_index >= 0)
    return export_index

func _nearest_tile_index(target_position: Vector3, tile_entries: Array[Dictionary]) -> int:
    var nearest_index: int = -1
    var nearest_distance_squared: float = INF
    for tile_index in range(tile_entries.size()):
        var tile_position: Vector3 = tile_entries[tile_index].get("position", Vector3.ZERO)
        var distance_squared: float = target_position.distance_squared_to(tile_position)
        if distance_squared >= nearest_distance_squared:
            continue
        nearest_index = tile_index
        nearest_distance_squared = distance_squared
    return nearest_index
