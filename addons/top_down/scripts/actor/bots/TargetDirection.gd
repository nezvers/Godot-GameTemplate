class_name TargetDirection
extends Node

@export var target_finder:TargetFinder
@export var bot_input:BotInput
@export var raycast:RayCast2D
@export var tile_navigation:TileNavigationGetter
## Value used to change recalculation cooldown
@export var retarget_distance:float = 16.0
@export var debug:bool


## From bot to target
var local_direction:Vector2
## Track targets position
var last_target_position:Vector2
## Time last navigation update happened
var last_update_time:float
var navigation_cooldown:float = 1.0



func _ready()->void:
	target_finder.target_update.connect(on_target_update)

func set_direction(direction:Vector2)->void:
	bot_input.mover.input_resource.set_axis((direction * bot_input.axis_compensation).normalized())

func on_target_update()->void:
	if target_finder.target_count < 1:
		set_direction(Vector2.ZERO)
		return
	local_direction = target_finder.closest.global_position - bot_input.global_position
	var local_dir_len:float = local_direction.length_squared()
	var attack_dist_squared:float = bot_input.attack_distance * bot_input.attack_distance
	
	if (local_dir_len < attack_dist_squared):
		set_direction(Vector2.ZERO)
		return
	
	#if line_of_sight():
		#set_direction(local_direction)
		#return
	
	navigation_update()
	var point:Vector2 = tile_navigation.get_next_path_position(bot_input.global_position)
	var direction:Vector2 = (point - bot_input.global_position)
	set_direction(direction)

## Raycast checks if anything from environment is in the way
func line_of_sight()->bool:
	raycast.target_position = local_direction
	raycast.force_raycast_update()
	return !raycast.is_colliding()

func navigation_update()->void:
	var time: = Time.get_ticks_msec() * 0.001
	if last_update_time + navigation_cooldown > time:
		return
	last_update_time = time
	# the bigger distance overshoot, the sooner update happens
	var moved_direction:Vector2 = (last_target_position - target_finder.closest.global_position)
	var ratio:float = (retarget_distance) / max(moved_direction.length(), 1.0)
	navigation_cooldown = min(ratio, 5.0)
	last_target_position = target_finder.closest.global_position
	tile_navigation.get_target_path(bot_input.global_position, last_target_position)
	#navigation_agent.target_position = last_target_position
