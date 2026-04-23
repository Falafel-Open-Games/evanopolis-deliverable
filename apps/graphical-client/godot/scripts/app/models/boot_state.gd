extends RefCounted

## Typed runtime model for boot-state updates published by AppBoot.

var title: String
var detail: String
var note: String

func _init(
    title: String,
    detail: String,
    note: String
) -> void:
    self.title = title
    self.detail = detail
    self.note = note

func clone():
    return get_script().new(title, detail, note)
