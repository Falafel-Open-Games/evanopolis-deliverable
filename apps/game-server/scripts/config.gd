class_name Config
extends RefCounted

const DEFAULT_BOARD_SIZE: int = 24

var game_id: String = ""
var board_size: int = 0
var player_count: int = 0


func _init(initial_game_id: String = "", initial_player_count: int = 0, initial_board_size: int = DEFAULT_BOARD_SIZE) -> void:
	game_id = initial_game_id
	player_count = initial_player_count
	board_size = initial_board_size


static func from_values(initial_game_id: String, initial_player_count: int, initial_board_size: int = DEFAULT_BOARD_SIZE) -> Config:
	return Config.new(initial_game_id, initial_player_count, initial_board_size)


func load_from_dictionary(data: Dictionary) -> void:
	game_id = str(data.get("game_id", ""))
	player_count = int(data.get("player_count", 0))
	var experimental: Dictionary = data.get("experimental", { })
	var board_size_value: int = int(data.get("board_size", 0))
	if board_size_value <= 0 and typeof(experimental) == TYPE_DICTIONARY:
		board_size_value = int(experimental.get("board_size", 0))
	if board_size_value <= 0:
		board_size_value = DEFAULT_BOARD_SIZE
	board_size = board_size_value
