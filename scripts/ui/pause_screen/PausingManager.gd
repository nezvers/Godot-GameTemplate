class_name PausingManager
extends Node

@export var pause_bool_resource:BoolResource
@export var pause_root:CanvasItem
@export var resume_button:Button

func _ready()->void:
	pause_bool_resource.reset_resource()
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_bool_resource.updated.connect(pause_changed)
	pause_changed()
	resume_button.pressed.connect(resume)

func _input(event:InputEvent)->void:
	if event.is_action_released("pause_game"):
		pause_bool_resource.set_value(!pause_bool_resource.value)

func resume()->void:
	pause_bool_resource.set_value(false)

func pause_changed()->void:
	var is_paused:bool = pause_bool_resource.value
	pause_root.visible = is_paused
	pause_root.process_mode = Node.PROCESS_MODE_ALWAYS if is_paused else Node.PROCESS_MODE_DISABLED
