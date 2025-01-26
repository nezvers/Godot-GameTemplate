@tool
extends EditorPlugin

const MANAGER_PANEL = preload("res://addons/resource_manager/scenes/manager_panel.tscn")

var manager_panel:Control

func _enter_tree() -> void:
	manager_panel = MANAGER_PANEL.instantiate()
	manager_panel.name = "Resource Manager"
	
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, manager_panel)


func _exit_tree() -> void:
	remove_control_from_docks(manager_panel)
	manager_panel.queue_free()
