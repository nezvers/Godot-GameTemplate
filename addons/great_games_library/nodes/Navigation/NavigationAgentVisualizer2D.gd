class_name NavigationAgentVisualizer2D
extends Line2D

@export var enabled:bool
@export var navigation_agent:NavigationAgent2D

func _ready()->void:
	top_level = true
	global_position = Vector2.ZERO
	set_enabled(enabled)

func set_enabled(value:bool)->void:
	enabled = value
	visible = enabled
	if enabled:
		if !navigation_agent.path_changed.is_connected(update_path):
			navigation_agent.path_changed.connect(update_path)
	else:
		if navigation_agent.path_changed.is_connected(update_path):
			navigation_agent.path_changed.disconnect(update_path)

func update_path()->void:
	points = navigation_agent.get_current_navigation_path()
