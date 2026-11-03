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
	var _tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(position_node.global_position)
	# a solid start gives no path, so standing in a blocked cell (wall overlap, next to a prop) starts from a free one
	var _from_tile:Vector2i = _free_tile_near(_tile)
	var _to_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(to)
	# partial: a target standing in a blocked cell still gets a path to the closest free cell
	navigation_path = astargrid_resource.value.get_point_path(_from_tile, _to_tile, true)
	tile_path = astargrid_resource.value.get_id_path(_from_tile, _to_tile, true)

	# walk to the free start cell first when it isn't the one the actor stands in
	if navigation_path.size() > 1 && _from_tile == _tile:
		index = 1
	else:
		index = 0
	
	finish_reached = false
	if visible:
		points = navigation_path
	return navigation_path

## The tile itself when free, else the free tile within 2 rings whose center is closest to the actor
func _free_tile_near(tile:Vector2i)->Vector2i:
	var _astar:AStarGrid2D = astargrid_resource.value
	if !_astar.region.has_point(tile) || !_astar.is_point_solid(tile):
		return tile
	var _tilemap:TileMapLayer = astargrid_resource.tilemap_layer
	var _position:Vector2 = _tilemap.to_local(position_node.global_position)
	for _ring:int in [1, 2]:
		var _best:Vector2i = tile
		var _best_distance:float = INF
		for _x:int in range(-_ring, _ring + 1):
			for _y:int in range(-_ring, _ring + 1):
				var _cell:Vector2i = tile + Vector2i(_x, _y)
				if maxi(absi(_x), absi(_y)) != _ring || !_astar.region.has_point(_cell) || _astar.is_point_solid(_cell):
					continue
				var _distance:float = _tilemap.map_to_local(_cell).distance_squared_to(_position)
				if _distance < _best_distance:
					_best_distance = _distance
					_best = _cell
		if _best != tile:
			return _best
	return tile

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
