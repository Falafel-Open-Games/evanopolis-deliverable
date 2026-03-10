class_name PlayerState
extends RefCounted

var player_index: int
var fiat_balance: float = 0.0
var bitcoin_balance: float = 0.0
var position: int = 0
var laps: int = 0
var in_inspection: bool = false
var inspection_free_exits: int = 0


func _init(index: int = -1) -> void:
    player_index = index
