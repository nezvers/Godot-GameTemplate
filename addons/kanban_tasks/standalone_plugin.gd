#@standalone
# The line above is needed for standalone detection. Do not modify it.
@tool
extends EditorPlugin

## The StandalonePlugin implementation for in editor use.
##
## This file violates DRY. It should not contain references to other files
## of standalone plugin. This allows the independent use as editor plugin.


## Additional containers for add_control_to_container
# CONTAINER_TOOLBAR = 0,
# CONTAINER_SPATIAL_EDITOR_MENU = 1,
# CONTAINER_SPATIAL_EDITOR_SIDE_LEFT = 2,
# CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT = 3,
# CONTAINER_SPATIAL_EDITOR_BOTTOM = 4,
# CONTAINER_CANVAS_EDITOR_MENU = 5,
# CONTAINER_CANVAS_EDITOR_SIDE_LEFT = 6,
# CONTAINER_CANVAS_EDITOR_SIDE_RIGHT = 7,
# CONTAINER_CANVAS_EDITOR_BOTTOM = 8,
# CONTAINER_INSPECTOR_BOTTOM = 9,
# CONTAINER_PROJECT_SETTING_TAB_LEFT = 10,
# CONTAINER_PROJECT_SETTING_TAB_RIGHT = 11,
const CONTAINER_LAUNCH_PAD := 12


func save_project_settings() -> int:
	return ProjectSettings.save()


func add_menu(menu: PopupMenu) -> void:
	pass


func remove_menu(menu: PopupMenu) -> void:
	pass
