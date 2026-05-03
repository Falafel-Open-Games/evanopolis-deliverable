class_name GameRoot
extends Node3D

const TopBarView = preload("res://scripts/game/hud/top_bar.gd")
const PlayersListPanelView = preload("res://scripts/game/hud/players_list_panel.gd")
const PawnCollectionView = preload("res://scripts/game/pawns/pawn_collection.gd")
const EventLogPanelView = preload("res://scripts/game/hud/event_log_panel.gd")

signal roll_dice_requested()
signal end_turn_requested()

@onready var board_root: Node3D = get_node(^"BoardRoot")
@onready var pawn_root: Node3D = get_node(^"PawnRoot")
@onready var pawn_collection: PawnCollectionView = get_node(^"PawnRoot/pawns")
@onready var hud_root: CanvasLayer = get_node(^"HudRoot")
@onready var camera_rig: Node3D = get_node(^"CameraRig")

@onready var top_bar: TopBarView = get_node("HudRoot/SafeMargin/VBoxContainer/TopBar")
@onready var players_list_panel: PlayersListPanelView = get_node(^"HudRoot/SafeMargin/VBoxContainer/PlayersList")
@onready var event_log_panel: EventLogPanelView = get_node(^"HudRoot/SafeMargin/VBoxContainer/EventLog")
@onready var roll_dice_button: Button = get_node(^"HudRoot/SafeMargin/TurnActions/HBoxContainer/RollDice")
@onready var sell_vs_mine_slider: HSlider = get_node(^"HudRoot/SafeMargin/TurnActions/HBoxContainer/SellVsMineSlider")
@onready var end_turn_button: Button = get_node(^"HudRoot/SafeMargin/TurnActions/HBoxContainer/EndTurn")

func _ready() -> void:
    assert(board_root)
    assert(pawn_root)
    assert(pawn_collection)
    assert(hud_root)
    assert(camera_rig)
    assert(top_bar)
    assert(players_list_panel)
    assert(event_log_panel)
    assert(roll_dice_button)
    assert(sell_vs_mine_slider)
    assert(end_turn_button)
    pawn_collection.bind_board_tiles(get_node(^"BoardRoot/tiles"))
    roll_dice_button.pressed.connect(_on_roll_dice_pressed)
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    set_turn_action_state(false, false)

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
    pawn_collection.sync_gameplay_player_states(player_states)

func set_event_log_messages(messages: Array) -> void:
    if not is_node_ready():
        call_deferred("set_event_log_messages", messages.duplicate())
        return
    event_log_panel.set_messages(messages)

func set_turn_action_state(can_roll_dice: bool, can_end_turn: bool) -> void:
    if not is_node_ready():
        call_deferred("set_turn_action_state", can_roll_dice, can_end_turn)
        return
    roll_dice_button.disabled = not can_roll_dice
    sell_vs_mine_slider.editable = false
    end_turn_button.disabled = not can_end_turn

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

    print_debug(
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
    return OS.has_environment("EVANOPOLIS_DEBUG_GAMEPLAY")

func _on_roll_dice_pressed() -> void:
    roll_dice_button.disabled = true
    roll_dice_requested.emit()

func _on_end_turn_pressed() -> void:
    end_turn_button.disabled = true
    end_turn_requested.emit()
