class_name TargetDirection
extends Node

@export var target_finder:TargetFinder
@export var bot_input:BotInput
@export var raycast:RayCast2D
@export var tile_navigation:TileNavigationGetter
## Value used to change recalculation cooldown
@export var retarget_distance:float = 16.0
@export var straight_path_distance:float = 16.0 * 5.0
@export var debug:bool


## From bot to target
var target_direction:Vector2
## Track targets position
var last_target_position:Vector2
## Time last navigation update happened
var last_update_time:float
var navigation_cooldown:float = 1.0
## Used to control navigation around corners
var allow_straight_path:bool = false

func _ready()->void:
	target_finder.target_update.connect(on_target_update)

func set_direction(direction:Vector2)->void:
	bot_input.input_resource.set_axis((direction * bot_input.axis_compensation).normalized())

func on_target_update()->void:
	if target_finder.target_count < 1:
		set_direction(Vector2.ZERO)
		return
	target_direction = target_finder.closest.global_position - bot_input.global_position
	
	if test_line_of_sight():
		set_direction(target_direction)
		return
	
	navigation_update()
	var point:Vector2 = tile_navigation.get_next_path_position(bot_input.global_position)
	var direction:Vector2 = (point - bot_input.global_position)
	set_direction(direction)

## Raycast checks if anything from environment is in the way
func test_line_of_sight()->bool:
	raycast.target_position = target_direction
	raycast.force_raycast_update()
	
	var _is_line_of_sight:bool = !raycast.is_colliding()
	if !_is_line_of_sight:
		allow_straight_path = false
	
	if tile_navigation.navigation_path.is_empty():
		return _is_line_of_sight
	if tile_navigation.finish_reached:
		return _is_line_of_sight
	if !(tile_navigation.index < tile_navigation.navigation_path.size() - 1):
		return _is_line_of_sight
	
	if _is_line_of_sight && !allow_straight_path && tile_navigation.point_reached:
		# use tile Vector2i positions for dot product to have straight angles
		var _target_tile_direction:Vector2 = (target_direction / tile_navigation.astargrid_resource.value.cell_size).round()
		var _point_direction:Vector2 = tile_navigation.tile_path[tile_navigation.index + 1] - tile_navigation.tile_path[tile_navigation.index]
		var _dot_product:float = _target_tile_direction.normalized().dot(_point_direction.normalized())
		if _dot_product > 0.5:
			allow_straight_path = true
	
	return allow_straight_path

func navigation_update()->void:
	var time: = Time.get_ticks_msec() * 0.001
	if last_update_time + navigation_cooldown > time:
		return
	last_update_time = time
	# the bigger distance overshoot, the sooner update happens
	# TODO: Something is off with too long cooldown
	var moved_direction:Vector2 = (last_target_position - target_finder.closest.global_position)
	var ratio:float = (retarget_distance) / max(moved_direction.length(), 1.0)
	navigation_cooldown = min(ratio, 5.0)
	last_target_position = target_finder.closest.global_position
	tile_navigation.get_target_path(last_target_position)
