extends Control

const BootStateModel = preload("res://scripts/app/models/boot_state.gd")

## Minimal default presentation for AppBoot.
##
## This script is optional. It listens to the boot controller signals and maps
## the published state into labels. Remove this node or replace the script if a
## different boot presentation is needed.

@export var boot_node_path: NodePath = NodePath("../..")

@onready var status_label: Label = %StatusLabel
@onready var detail_label: Label = %DetailLabel
@onready var note_label: Label = %NoteLabel

var _boot_node: Node = null

func _ready() -> void:
    assert(status_label)
    assert(detail_label)
    assert(note_label)

    _boot_node = get_node(boot_node_path)
    assert(_boot_node)
    assert(_boot_node.has_signal("boot_state_changed"))
    assert(_boot_node.has_method("get_boot_state"))

    _boot_node.connect("boot_state_changed", Callable(self, "_on_boot_state_changed"))
    _render_boot_state(_boot_node.call("get_boot_state"))

func _on_boot_state_changed(state: BootStateModel) -> void:
    _render_boot_state(state)

func _render_boot_state(state: BootStateModel) -> void:
    status_label.text = state.title
    detail_label.text = state.detail
    note_label.text = state.note
