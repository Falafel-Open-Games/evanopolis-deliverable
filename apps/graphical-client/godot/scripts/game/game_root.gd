class_name GameRoot
extends Node3D

const TopBarView = preload("res://scripts/game/hud/top_bar.gd")
const PlayersListPanelView = preload("res://scripts/game/hud/players_list_panel.gd")
const PawnCollectionView = preload("res://scripts/game/pawns/pawn_collection.gd")
const EventLogPanelView = preload("res://scripts/game/hud/event_log_panel.gd")
const EnergyAllocationView = preload("res://scripts/game/hud/energy_allocation.gd")
const TurnActionsView = preload("res://scripts/game/hud/turn_actions.gd")
const DEBUG_GAMEPLAY_ARGUMENT: String = "--debug"
const DIE_FACE_NORMALS: Dictionary = {
    1: Vector3.DOWN,
    2: Vector3.RIGHT,
    3: Vector3.BACK,
    4: Vector3.FORWARD,
    5: Vector3.LEFT,
    6: Vector3.UP,
}

signal roll_dice_requested()
signal end_turn_requested()
signal buy_property_requested(tile_index: int)
signal pay_toll_requested()
signal energy_allocation_requested(sell_percent: int)

@onready var board_root: Node3D = get_node(^"BoardRoot")
@onready var top_tiles_root: Node3D = get_node(^"BoardRoot/tiles")
@onready var bottom_tiles_root: Node3D = get_node(^"BoardRoot/BottomTiles")
@onready var dice_root: Node3D = get_node(^"BoardRoot/Dices")
@onready var die_a: Node3D = get_node(^"BoardRoot/Dices/D6A")
@onready var die_b: Node3D = get_node(^"BoardRoot/Dices/D6B")
@onready var pawn_root: Node3D = get_node(^"PawnRoot")
@onready var pawn_collection: PawnCollectionView = get_node(^"PawnRoot/pawns")
@onready var hud_root: CanvasLayer = get_node(^"HudRoot")
@onready var camera_rig: Node3D = get_node(^"CameraRig")
@onready var energy_allocation: EnergyAllocationView = find_child("EnergyAllocation", true, false) as EnergyAllocationView

@export var top_bar: TopBarView
@export var players_list_panel: PlayersListPanelView
@export var event_log_panel: EventLogPanelView
@export var turn_actions: TurnActionsView

var _player_color_ids_by_index: Dictionary = { }
var _tile_owner_indices_by_tile_index: Dictionary = { }
var _top_tile_nodes_by_index: Dictionary = { }
var _top_tile_original_transforms_by_index: Dictionary = { }
var _bottom_tile_nodes_by_index: Dictionary = { }
var _bottom_tile_heights_by_index: Array[float] = []

func _ready() -> void:
    assert(board_root)
    assert(top_tiles_root)
    assert(bottom_tiles_root)
    assert(dice_root)
    assert(die_a)
    assert(die_b)
    assert(pawn_root)
    assert(pawn_collection)
    assert(hud_root)
    assert(camera_rig)
    assert(energy_allocation)
    assert(turn_actions)
    assert(top_bar)
    assert(players_list_panel)
    assert(event_log_panel)
    pawn_collection.bind_board_tiles(top_tiles_root)
    _capture_tile_stack_nodes()
    _apply_property_stack_visuals()
    turn_actions.roll_dice_requested.connect(_on_roll_dice_pressed)
    turn_actions.buy_property_requested.connect(_on_buy_property_pressed)
    turn_actions.pay_toll_requested.connect(_on_pay_toll_pressed)
    turn_actions.end_turn_requested.connect(_on_end_turn_pressed)
    energy_allocation.allocation_requested.connect(_on_energy_allocation_requested)
    set_turn_action_state(false, false, false, { })
    set_energy_allocation_state(50, false, 0.0, 0.0, false, false)
    set_dice_values(6, 6)

func set_local_player_identity(icon_id: int, color_id: int) -> void:
    if not is_node_ready():
        call_deferred("set_local_player_identity", icon_id, color_id)
        return
    top_bar.set_local_player_identity(icon_id, color_id)

func set_turn_info(turn_number: int, player_name: String, is_local_turn: bool, current_player_index: int) -> void:
    if not is_node_ready():
        call_deferred("set_turn_info", turn_number, player_name, is_local_turn, current_player_index)
        return
    top_bar.set_turn_info(turn_number, player_name, is_local_turn)
    players_list_panel.set_current_turn_player_index(current_player_index)

func set_dice_values(die_1: int, die_2: int) -> void:
    if not is_node_ready():
        call_deferred("set_dice_values", die_1, die_2)
        return
    _set_die_face_up(die_a, die_1)
    _set_die_face_up(die_b, die_2)

func set_player_states(player_states: Array) -> void:
    if not is_node_ready():
        call_deferred("set_player_states", player_states.duplicate())
        return
    _player_color_ids_by_index.clear()
    for state_variant in player_states:
        if state_variant == null:
            continue
        _player_color_ids_by_index[int(state_variant.player_index)] = int(state_variant.color_id)
        if bool(state_variant.is_local):
            top_bar.set_local_player_resources(
                float(state_variant.fiat_balance),
                int(state_variant.energy_amount),
                float(state_variant.bitcoin_balance)
            )
    players_list_panel.set_player_states(player_states)
    pawn_collection.sync_gameplay_player_states(player_states)
    _apply_property_stack_visuals()

func set_tile_owner_indices(tile_owner_indices_by_tile_index: Dictionary) -> void:
    if not is_node_ready():
        call_deferred("set_tile_owner_indices", tile_owner_indices_by_tile_index.duplicate(true))
        return
    _tile_owner_indices_by_tile_index = tile_owner_indices_by_tile_index.duplicate(true)
    _apply_property_stack_visuals()

func set_event_log_messages(messages: Array) -> void:
    if not is_node_ready():
        call_deferred("set_event_log_messages", messages.duplicate())
        return
    event_log_panel.set_messages(messages)

func set_turn_action_state(can_roll_dice: bool, can_end_turn: bool, is_local_turn: bool, property_action: Dictionary = { }) -> void:
    if not is_node_ready():
        call_deferred("set_turn_action_state", can_roll_dice, can_end_turn, is_local_turn, property_action.duplicate(true))
        return
    turn_actions.set_turn_action_state(can_roll_dice, can_end_turn, is_local_turn, property_action)

func set_energy_allocation_state(
    sell_percent: int,
    can_edit: bool,
    sell_100_fiat_total: float,
    mine_100_btc_total: float,
    is_request_pending: bool,
    should_show: bool
) -> void:
    if not is_node_ready():
        call_deferred(
            "set_energy_allocation_state",
            sell_percent,
            can_edit,
            sell_100_fiat_total,
            mine_100_btc_total,
            is_request_pending,
            should_show
        )
        return
    energy_allocation.set_energy_allocation_state(
        sell_percent,
        can_edit,
        sell_100_fiat_total,
        mine_100_btc_total,
        is_request_pending,
        should_show
    )

func set_pawn_tile_positions(tile_positions_by_player_index: Dictionary) -> void:
    if not is_node_ready():
        call_deferred("set_pawn_tile_positions", tile_positions_by_player_index.duplicate())
        return
    pawn_collection.sync_authoritative_tile_positions(tile_positions_by_player_index)

func set_pawn_tile_position(player_index: int, tile_index: int) -> void:
    if not is_node_ready():
        call_deferred("set_pawn_tile_position", player_index, tile_index)
        return
    pawn_collection.set_pawn_tile_index(player_index, tile_index)

func debug_print_visible_state(
    context: String,
    local_player_id: String,
    local_icon_id: int,
    local_color_id: int,
    turn_state: Dictionary,
    player_states: Array,
    event_log_messages: Array,
    tile_positions_by_player_index: Dictionary
) -> void:
    if not is_node_ready():
        call_deferred(
            "debug_print_visible_state",
            context,
            local_player_id,
            local_icon_id,
            local_color_id,
            turn_state.duplicate(true),
            player_states.duplicate(),
            event_log_messages.duplicate(),
            tile_positions_by_player_index.duplicate(true)
        )
        return
    if not _should_print_debug_gameplay_state():
        return

    var player_summaries: Array[String] = []
    for state_variant in player_states:
        if state_variant == null:
            continue
        player_summaries.append(
            "p%d%s %s color=%d fiat=%.2f energy=%d btc=%.8f" % [
                int(state_variant.player_index),
                " local" if bool(state_variant.is_local) else "",
                String(state_variant.display_name),
                int(state_variant.color_id),
                float(state_variant.fiat_balance),
                int(state_variant.energy_amount),
                float(state_variant.bitcoin_balance),
            ]
        )

    var pawn_summaries: Array[String] = []
    var pawn_player_indices: Array = tile_positions_by_player_index.keys()
    pawn_player_indices.sort()
    for player_index_variant in pawn_player_indices:
        pawn_summaries.append("p%d->%d" % [
            int(player_index_variant),
            int(tile_positions_by_player_index[player_index_variant]),
        ])

    var event_tail: Array[String] = []
    var start_index: int = max(0, event_log_messages.size() - 4)
    for event_index in range(start_index, event_log_messages.size()):
        event_tail.append(str(event_log_messages[event_index]))

    print(
        "[visible:%s] local_id=%s icon=%d color=%d turn=%d current=%d local_turn=%s can_roll=%s pending=%s/%d players=[%s] pawns=[%s] events=[%s]" % [
            context,
            local_player_id,
            local_icon_id,
            local_color_id,
            int(turn_state.get("turn_number", -1)),
            int(turn_state.get("current_player_index", -1)),
            bool(turn_state.get("is_local_turn", false)),
            bool(turn_state.get("can_roll_dice", false)),
            str(turn_state.get("pending_action_type", "")),
            int(turn_state.get("pending_action_tile_index", -1)),
            ", ".join(player_summaries),
            ", ".join(pawn_summaries),
            " | ".join(event_tail),
        ]
    )
    pawn_collection.debug_print_pawn_layout(context)


func _should_print_debug_gameplay_state() -> bool:
    return OS.has_environment("EVANOPOLIS_DEBUG_GAMEPLAY") or _has_debug_argument()

func _has_debug_argument() -> bool:
    for argument in OS.get_cmdline_args():
        if argument == DEBUG_GAMEPLAY_ARGUMENT or argument.begins_with("%s=" % DEBUG_GAMEPLAY_ARGUMENT):
            return true
    for argument in OS.get_cmdline_user_args():
        if argument == DEBUG_GAMEPLAY_ARGUMENT or argument.begins_with("%s=" % DEBUG_GAMEPLAY_ARGUMENT):
            return true
    return false

func _on_energy_allocation_requested(sell_percent: int) -> void:
    energy_allocation_requested.emit(sell_percent)

func _set_die_face_up(die_node: Node3D, face_value: int) -> void:
    assert(die_node != null)
    assert(DIE_FACE_NORMALS.has(face_value))
    die_node.basis = _basis_for_face_up(face_value)

func _basis_for_face_up(face_value: int) -> Basis:
    assert(DIE_FACE_NORMALS.has(face_value))
    var face_normal: Vector3 = DIE_FACE_NORMALS[face_value]
    if face_normal == Vector3.UP:
        return Basis.IDENTITY
    if face_normal == Vector3.DOWN:
        return Basis(Vector3.FORWARD, PI)
    var rotation_axis: Vector3 = face_normal.cross(Vector3.UP).normalized()
    return Basis(rotation_axis, PI * 0.5)

func _capture_tile_stack_nodes() -> void:
    _top_tile_nodes_by_index = _resolve_tile_nodes_by_index(top_tiles_root, "TileInstance")
    _bottom_tile_nodes_by_index = _resolve_tile_nodes_by_index(bottom_tiles_root)
    _top_tile_original_transforms_by_index.clear()
    for tile_index_variant in _top_tile_nodes_by_index.keys():
        var tile_index: int = int(tile_index_variant)
        var top_tile: Node3D = _top_tile_nodes_by_index[tile_index_variant] as Node3D
        assert(top_tile != null)
        _top_tile_original_transforms_by_index[tile_index] = top_tile.transform

    var max_tile_index: int = -1
    for tile_index_variant in _bottom_tile_nodes_by_index.keys():
        max_tile_index = max(max_tile_index, int(tile_index_variant))
    _bottom_tile_heights_by_index.clear()
    _bottom_tile_heights_by_index.resize(max_tile_index + 1)
    bottom_tiles_root.visible = true
    for tile_index_variant in _bottom_tile_nodes_by_index.keys():
        var tile_index: int = int(tile_index_variant)
        var bottom_tile: Node3D = _bottom_tile_nodes_by_index[tile_index_variant] as Node3D
        assert(bottom_tile != null)
        _bottom_tile_heights_by_index[tile_index] = _node_visual_height(bottom_tile)
        bottom_tile.visible = false
    pawn_collection.set_tile_height_offsets(_bottom_tile_heights_by_index)

func _apply_property_stack_visuals() -> void:
    if _bottom_tile_nodes_by_index.is_empty():
        return

    var tile_height_offsets: Array[float] = []
    tile_height_offsets.resize(_bottom_tile_heights_by_index.size())
    for tile_index_variant in _bottom_tile_nodes_by_index.keys():
        var tile_index: int = int(tile_index_variant)
        var bottom_tile: Node3D = _bottom_tile_nodes_by_index[tile_index_variant] as Node3D
        assert(bottom_tile != null)

        var is_owned: bool = _tile_owner_indices_by_tile_index.has(tile_index)
        bottom_tile.visible = is_owned
        if is_owned:
            var owner_index: int = int(_tile_owner_indices_by_tile_index[tile_index])
            var owner_color_id: int = int(_player_color_ids_by_index.get(owner_index, -1))
            var owner_material: Material = pawn_collection.duplicate_material_for_color_id(owner_color_id)
            if owner_material != null:
                _apply_material_to_meshes(bottom_tile, owner_material)
            tile_height_offsets[tile_index] = float(_bottom_tile_heights_by_index[tile_index])

        if _top_tile_nodes_by_index.has(tile_index):
            var top_tile: Node3D = _top_tile_nodes_by_index[tile_index] as Node3D
            assert(top_tile != null)
            var original_transform: Transform3D = _top_tile_original_transforms_by_index[tile_index]
            var stacked_transform: Transform3D = original_transform
            stacked_transform.origin += stacked_transform.basis.y.normalized() * tile_height_offsets[tile_index]
            top_tile.transform = stacked_transform

    pawn_collection.set_tile_height_offsets(tile_height_offsets)

func _resolve_tile_nodes_by_index(root: Node3D, required_prefix: String = "") -> Dictionary:
    var tile_nodes_by_index: Dictionary = { }
    _collect_tile_nodes_by_index(root, tile_nodes_by_index, required_prefix)
    return tile_nodes_by_index

func _collect_tile_nodes_by_index(node: Node, tile_nodes_by_index: Dictionary, required_prefix: String) -> void:
    for child in node.get_children():
        var node3d: Node3D = child as Node3D
        if node3d == null:
            continue
        var node_name: String = String(node3d.name)
        var tile_index: int = _node_export_index(node3d)
        if tile_index >= 0 and (required_prefix.is_empty() or node_name.begins_with(required_prefix)):
            tile_nodes_by_index[tile_index] = node3d
            continue
        _collect_tile_nodes_by_index(node3d, tile_nodes_by_index, required_prefix)

func _node_export_index(node: Node) -> int:
    var node_name: String = String(node.name)
    var suffix_text: String = ""
    var underscore_index: int = node_name.rfind("_")
    if underscore_index >= 0 and underscore_index < node_name.length() - 1:
        suffix_text = node_name.substr(underscore_index + 1)
    else:
        for character_index in range(node_name.length() - 1, -1, -1):
            var character: String = node_name.substr(character_index, 1)
            if not character.is_valid_int():
                break
            suffix_text = "%s%s" % [character, suffix_text]
    if suffix_text.is_empty() or not suffix_text.is_valid_int():
        return -1
    return int(suffix_text)

func _node_visual_height(node: Node3D) -> float:
    var min_y: float = INF
    var max_y: float = -INF
    var meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(node, meshes)
    for mesh_instance in meshes:
        var mesh_aabb: AABB = mesh_instance.get_aabb()
        for corner_index in range(8):
            var corner: Vector3 = mesh_aabb.position + Vector3(
                mesh_aabb.size.x if (corner_index & 1) != 0 else 0.0,
                mesh_aabb.size.y if (corner_index & 2) != 0 else 0.0,
                mesh_aabb.size.z if (corner_index & 4) != 0 else 0.0
            )
            var corner_global: Vector3 = mesh_instance.global_transform * corner
            min_y = min(min_y, corner_global.y)
            max_y = max(max_y, corner_global.y)
    if min_y == INF or max_y == -INF:
        return 0.0
    return max(0.0, max_y - min_y)

func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
    for child in node.get_children():
        var mesh_instance: MeshInstance3D = child as MeshInstance3D
        if mesh_instance != null:
            result.append(mesh_instance)
            continue
        _collect_mesh_instances(child, result)

func _apply_material_to_meshes(node: Node, material: Material) -> void:
    for child in node.get_children():
        var mesh_instance: MeshInstance3D = child as MeshInstance3D
        if mesh_instance != null:
            mesh_instance.material_override = material
            continue
        _apply_material_to_meshes(child, material)

func _on_roll_dice_pressed() -> void:
    roll_dice_requested.emit()

func _on_buy_property_pressed(tile_index: int) -> void:
    buy_property_requested.emit(tile_index)

func _on_pay_toll_pressed() -> void:
    pay_toll_requested.emit()

func _on_end_turn_pressed() -> void:
    end_turn_requested.emit()
