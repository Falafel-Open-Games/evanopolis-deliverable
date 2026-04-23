extends RefCounted

## Typed runtime model for the visible status card text.

var title: String
var detail: String
var note: String

func _init(initial_title: String, initial_detail: String, initial_note: String) -> void:
    title = initial_title
    detail = initial_detail
    note = initial_note

func clone():
    return get_script().new(title, detail, note)
