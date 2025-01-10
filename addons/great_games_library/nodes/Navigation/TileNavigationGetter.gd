class_name TileNavigationGetter
extends Line2D

@export var position_node:Node2D
@export var astargrid_resource:AstarGridResource

## How close to be to a point to look up next one
@export var reached_distance:float = 6.0

var navigation_path:PackedVector2Array
var tile_path:Array[Vector2i]
var index:int = 0
var closest_point:Vector2
var finish_reached:bool : set = set_finish_reached
var point_reached:bool

func set_finish_reached(value:bool)->void:
	finish_reached = value

func _ready()->void:
	## To draw lines without moving them
	top_level = true
	global_position = Vector2.ZERO
	
	# in case used with PoolNode
	request_ready()

func get_target_path(to:Vector2)->PackedVector2Array:
	var _from_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(position_node.global_position)
	var _to_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(to)
	navigation_path = astargrid_resource.value.get_point_path(_from_tile, _to_tile)
	tile_path = astargrid_resource.value.get_id_path(_from_tile, _to_tile)
	
	if navigation_path.size() > 1:
		index = 1
	else:
		index = 0
	
	finish_reached = false
	if visible:
		points = navigation_path
	return navigation_path

## TODO: Don't use top_level to be able use position
##
func get_next_path_position(from:Vector2)->Vector2:
	if navigation_path.is_empty():
		return position_node.global_position
	
	## TODO: add corner avoidance steering
	closest_point = navigation_path[index]
	var _closest_dist:float = (closest_point - from).length_squared()
	var _treshold:float = reached_distance * reached_distance
	
	var i:int = index
	if _closest_dist < _treshold && i < navigation_path.size() - 1:
		i += 1
		assert(i < navigation_path.size())
		closest_point = navigation_path[i]
	
	if i != index:
		point_reached = true
		if index == navigation_path.size() - 1:
			finish_reached = true
	elif !finish_reached:
		point_reached = false
	
	index = i
	assert(i < navigation_path.size())
	return closest_point
