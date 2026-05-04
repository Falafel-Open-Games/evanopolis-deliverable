class_name PlayerState
extends RefCounted

var player_index: int
var display_name: String = ""
var icon_id: int = -1
var color_id: int = -1
var fiat_balance: float = 0.0
var bitcoin_balance: float = 0.0
var position: int = 0
var laps: int = 0
var landing_sequence: int = 0
var is_active: bool = true
var sell_percent: int = 50
var last_turn_number_allocation_changed: int = -1


func _init(index: int = -1) -> void:
    player_index = index
