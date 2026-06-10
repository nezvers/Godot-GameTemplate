## Drives the Difficulty toggle in the Options menu (modeled on GraphicsManager).
## Press cycles Normal <-> Easy, updates the label, and saves to disk.
extends Node

@export var difficulty_resource: DifficultyResource
@export var button: Button
@export var label: Label

func _ready() -> void:
	assert(difficulty_resource != null)
	assert(button != null)
	assert(label != null)
	button.pressed.connect(_on_pressed)
	difficulty_resource.updated.connect(_update_label)
	_update_label()

func _on_pressed() -> void:
	difficulty_resource.toggle()
	difficulty_resource.save_resource()

func _update_label() -> void:
	label.text = "Difficulty: " + difficulty_resource.mode_name()
