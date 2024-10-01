extends Node

@export var menu_traverse_manager:MenuTraverseManager

func _input(event:InputEvent)->void:
	if event.is_action_released("ui_cancel") || event.is_action_released("pause_game"):
		if menu_traverse_manager.directory_resource.selected_directory != NodePath("."):
			menu_traverse_manager.back()
