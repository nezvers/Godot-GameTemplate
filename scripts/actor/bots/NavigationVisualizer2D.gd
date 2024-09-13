class_name NavigationVisualizer2D
extends Line2D

@export var navigation_agent:NavigationAgent2D

func _ready()->void:
	navigation_agent.path_changed.connect(update_path)

func update_path()->void:
	points = navigation_agent.get_current_navigation_path()
