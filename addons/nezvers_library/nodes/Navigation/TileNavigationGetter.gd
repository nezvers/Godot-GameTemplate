class_name TileNavigationGetter
extends Line2D

@export var astargrid_resource:AstarGridResource
## How close to be to a point to look up next one
@export var reached_distance:float = 6.0

var last_path:PackedVector2Array
var index:int = 0

func _ready()->void:
	top_level = true
	global_position = Vector2.ZERO

func get_target_path(from:Vector2, to:Vector2)->PackedVector2Array:
	var _from_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(from)
	var _to_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(to)
	last_path = astargrid_resource.value.get_point_path(_from_tile, _to_tile)
	index = 0
	if visible:
		points = last_path
	return last_path

func get_next_path_position(from:Vector2)->Vector2:
	if last_path.is_empty():
		return Vector2.ZERO
	
	## TODO: add corner avoidance steering
	var _closest_point:Vector2 = last_path[index]
	var _closest_dist:float = (_closest_point - from).length_squared()
	var _treshold:float = reached_distance * reached_distance
	var i:int = 0
	while i < last_path.size():
		index = i
		var _current_point = last_path[i]
		var _current_dist = (_current_point - from).length_squared()
		if _closest_dist < _current_dist && _closest_dist > _treshold:
			break
		_closest_point = _current_point
		_closest_dist = _current_dist
		i += 1 # <- don't forget
	return _closest_point

# closest
# if there's a next point, closest must be further than treshold
