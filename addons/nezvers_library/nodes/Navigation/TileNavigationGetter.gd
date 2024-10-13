class_name TileNavigationGetter
extends Line2D

@export var astargrid_resource:AstarGridResource
## How close to be to a point to look up next one
@export var reached_distance:float = 6.0

var last_path:PackedVector2Array
var index:int = 0
var closest_point:Vector2
var is_finished:bool

func _ready()->void:
	top_level = true
	global_position = Vector2.ZERO

func get_target_path(from:Vector2, to:Vector2)->PackedVector2Array:
	var _from_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(from)
	var _to_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(to)
	last_path = astargrid_resource.value.get_point_path(_from_tile, _to_tile)
	index = 0
	first_point_choice(from)
	
	is_finished = false
	if visible:
		points = last_path
	return last_path

## TODO: Don't use top_level to be able use position
##
func get_next_path_position(from:Vector2)->Vector2:
	if last_path.is_empty():
		return closest_point
	
	## TODO: add corner avoidance steering
	closest_point = last_path[index]
	var _closest_dist:float = (closest_point - from).length_squared()
	var _treshold:float = reached_distance * reached_distance
	var i:int = index +1
	while i < last_path.size():
		var _current_point = last_path[i]
		var _current_dist = (_current_point - from).length_squared()
		if _closest_dist < _current_dist:
			break
		closest_point = _current_point
		_closest_dist = _current_dist
		index = i
		i += 1 # <- don't forget, or else...
	
	if _closest_dist < _treshold && index < last_path.size() - 1:
		index += 1
		closest_point = last_path[index]
	else:
		is_finished = true
	
	return closest_point

## Solution to not go backwards for a first point
func first_point_choice(_position:Vector2)->void:
	if last_path.size() < 2:
		return
	var _dot_product:float = (last_path[0] - _position).normalized().dot((last_path[1] - _position).normalized())
	if _dot_product > 0.0:
		return
	index = 1
