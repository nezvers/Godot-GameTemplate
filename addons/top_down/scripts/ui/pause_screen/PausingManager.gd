class_name PausingManager
extends Node

@export var pause_bool_resource:BoolResource
@export var pause_root:CanvasItem
@export var resume_button:Button
@export var menu_traverse_manager:MenuTraverseManager

func _ready()->void:
	pause_bool_resource.reset_resource()
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_bool_resource.updated.connect(pause_changed)
	pause_changed()
	resume_button.pressed.connect(resume)
	tree_exiting.connect(pause_bool_resource.set_value.bind(false))

func _input(event:InputEvent)->void:
	if event.is_action_released("pause_game"):
		if pause_bool_resource.value == false:
			pause_bool_resource.set_value(true)
		elif menu_traverse_manager.directory_resource.selected_directory == NodePath("."):
			pause_bool_resource.set_value(false)
		else:
			menu_traverse_manager.back()
		return
	if pause_bool_resource.value == false:
		return
	if event.is_action_released("ui_cancel"):
		if menu_traverse_manager.directory_resource.selected_directory != NodePath("."):
			menu_traverse_manager.back()
		else:
			pause_bool_resource.set_value(false)
		return

func resume()->void:
	pause_bool_resource.set_value(false)

func pause_changed()->void:
	var is_paused:bool = pause_bool_resource.value
	pause_root.visible = is_paused
	pause_root.process_mode = Node.PROCESS_MODE_ALWAYS if is_paused else Node.PROCESS_MODE_DISABLED
