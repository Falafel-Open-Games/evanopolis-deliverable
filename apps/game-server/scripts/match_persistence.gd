class_name MatchPersistence
extends RefCounted


var root_path: String


func _init(persistence_root_path: String = "user://match_state") -> void:
    root_path = persistence_root_path


func save_snapshot(game_id: String, snapshot: Dictionary) -> void:
    if game_id.is_empty():
        return
    _ensure_root_exists()
    var file: FileAccess = FileAccess.open(_snapshot_path(game_id), FileAccess.WRITE)
    assert(file != null)
    file.store_string(JSON.stringify(snapshot))
    file.close()


func load_snapshot(game_id: String) -> Dictionary:
    var path: String = _snapshot_path(game_id)
    if not FileAccess.file_exists(path):
        return { }
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return { }
    var raw_snapshot: String = file.get_as_text()
    file.close()
    var parsed_snapshot: Variant = JSON.parse_string(raw_snapshot)
    if typeof(parsed_snapshot) != TYPE_DICTIONARY:
        return { }
    return parsed_snapshot


func delete_snapshot(game_id: String) -> void:
    if game_id.is_empty():
        return
    var path: String = _snapshot_path(game_id)
    if not FileAccess.file_exists(path):
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _ensure_root_exists() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))


func _snapshot_path(game_id: String) -> String:
    var safe_game_id: String = game_id.replace("/", "_")
    return root_path.path_join("%s.json" % safe_game_id)
