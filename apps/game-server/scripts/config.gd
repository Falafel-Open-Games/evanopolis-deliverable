class_name Config
extends RefCounted

const CONFIG_PATH: String = "res://config.toml"

var game_id: String = ""
var board_size: int = 0
var player_count: int = 0


func _init(path: String = CONFIG_PATH) -> void:
	load_from_file(path)


func load_from_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert(file)
	var text: String = file.get_as_text()
	var data: Dictionary = _parse_toml(text)
	game_id = str(data.get("game_id", ""))
	board_size = int(data.get("board_size", 0))
	player_count = int(data.get("player_count", 0))


func _parse_toml(text: String) -> Dictionary:
	var result: Dictionary = { }
	var lines: PackedStringArray = text.split("\n")
	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			continue
		var comment_index: int = line.find("#")
		if comment_index >= 0:
			line = line.substr(0, comment_index).strip_edges()
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split("=")
		if parts.size() < 2:
			continue
		var key: String = parts[0].strip_edges()
		var value_text: String = "=".join(parts.slice(1, parts.size())).strip_edges()
		var value: Variant = _parse_toml_value(value_text)
		result[key] = value
	return result


func _parse_toml_value(text: String) -> Variant:
	if text.begins_with("\"") and text.ends_with("\"") and text.length() >= 2:
		return text.substr(1, text.length() - 2)
	if text.is_valid_float():
		if text.find(".") >= 0:
			return float(text)
		return int(text)
	return text
