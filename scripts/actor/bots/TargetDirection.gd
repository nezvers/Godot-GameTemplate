class_name TargetDirection
extends Node

@export var target_finder:TargetFinder
@export var bot_input:BotInput
@export var attack_distance:float = 16.0
@export var raycast:RayCast2D
@export var navigation_agent:NavigationAgent2D

var detected: = false
var last_target_position:Vector2
var local_direction:Vector2

func _ready()->void:
	target_finder.target_update.connect(on_target_update)


func on_target_update()->void:
	if target_finder.closest == null:
		return
	local_direction = target_finder.closest.global_position - bot_input.global_position
	if local_direction.length() > attack_distance && line_of_sight():
		bot_input.mover.input_resource.set_axis((local_direction * bot_input.axis_compensation).normalized())
		bot_input.mover.input_resource.set_aim_direction(bot_input.mover.input_resource.axis)
		return
	navigation_update()

## Raycast checks if anything from environment is in the way
func line_of_sight()->bool:
	raycast.target_position = local_direction
	raycast.force_raycast_update()
	return !raycast.is_colliding()

func navigation_update()->void:
	if (navigation_agent.target_position - bot_input.global_position).length() > 16.0:
		navigation_agent.target_position = target_finder.closest.global_position
	var point:Vector2 = navigation_agent.get_next_path_position()
	var direction:Vector2 = (point - bot_input.global_position).normalized()
	bot_input.mover.input_resource.set_axis((direction * bot_input.axis_compensation).normalized())
	bot_input.mover.input_resource.set_aim_direction(bot_input.mover.input_resource.axis)
