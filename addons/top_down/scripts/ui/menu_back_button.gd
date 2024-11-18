extends Button

@export var menu_traverse_manager:MenuTraverseManager

func _pressed()->void:
	menu_traverse_manager.back()
