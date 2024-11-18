## Small script to go back in menu
extends Node

@export var menu_traverse_manager:MenuTraverseManager
@export var action_resource:ActionResource


func _input(event:InputEvent)->void:
	if event.is_action_released(action_resource.pause_action) || event.is_action_released("ui_cancel"):
		if menu_traverse_manager.directory_resource.selected_directory != NodePath("."):
			menu_traverse_manager.back()
