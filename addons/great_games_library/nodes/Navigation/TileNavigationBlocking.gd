## Collects tiles for obstacles and puts information into AStarGrid2D for navigation path calculations
class_name TileNavigationBlocking
extends Node

## TileMapLayer for creating obstacle tiles
@export var tilemap_layer:TileMapLayer
@export var astargrid_resource:AstarGridResource
@export var obstacle_shape:Shape2D

## Custom tile data name of PackedVector2Array for collider offsets
@export var data_name:String = "collider_offset"
@export_flags_2d_physics var collision_layer:int
@export_flags_2d_physics var collision_mask:int

## TODO: use data in tile_set for navigation weight informtion

var collider_rid_list:Array[RID]
var tile_data_names:Array[String]
var tiles:Array[Vector2i]

func _ready()-> void:
	assert(astargrid_resource != null)
	astargrid_resource.updated.connect(setup_obstacles)
	setup_obstacles.call_deferred()
	tree_exiting.connect(cleanup)
	astargrid_resource.cleanup_event.connect(cleanup)


func setup_obstacles()->void:
	if astargrid_resource.value == null:
		return
	var _astar:AStarGrid2D = astargrid_resource.value
	
	# Cache custom data names to later check if exist
	var _tile_data_count:int = tilemap_layer.tile_set.get_custom_data_layers_count()
	tile_data_names.resize(_tile_data_count)
	for i:int in _tile_data_count:
		tile_data_names[i] = tilemap_layer.tile_set.get_custom_data_layer_name(i)
	var _has_offset:bool = tile_data_names.has(data_name)
	
	# TileSet doesn't contain offset data
	if _has_offset == false:
		return
	
	tiles = tilemap_layer.get_used_cells()
	var _space:RID = tilemap_layer.get_world_2d().space
	var _id:int = get_instance_id()
	## For some reason kinematic is a must to work with Area2D, static didn't work
	var _body_mode:PhysicsServer2D.BodyMode = PhysicsServer2D.BODY_MODE_KINEMATIC
	
	for i:int in tiles.size():
		var _tile_pos:Vector2i = tiles[i]
		var _tile_data:TileData = tilemap_layer.get_cell_tile_data(_tile_pos)
		var _offset_list:PackedVector2Array
		if _has_offset:
			_offset_list = _tile_data.get_custom_data(data_name)
		
		for _offset:Vector2 in _offset_list:
			var _tile_pos_off:Vector2i = _tile_pos + Vector2i(_offset)
			
			assert(_astar.region.has_point(_tile_pos_off))
			_astar.set_point_solid(_tile_pos_off, true)
			var _pos:Vector2 = tilemap_layer.map_to_local(_tile_pos_off)
			var _transform:Transform2D = Transform2D(0.0, _pos)
			var _body_rid:RID = PhysicsHelper.body_create_2d(_space, collision_layer, collision_mask, obstacle_shape, _transform, _body_mode, _id)
			collider_rid_list.append(_body_rid)
	_astar.update()


## Free obstacles from AstarGrid & PhysicsServer
func cleanup() -> void:
	for _body_rid:RID in collider_rid_list:
		PhysicsServer2D.free_rid(_body_rid)
	collider_rid_list.clear()
	
	if astargrid_resource.value == null:
		return
	
	for i:int in tiles.size():
		var _tile_pos:Vector2i = tiles[i]
		astargrid_resource.value.set_point_solid(_tile_pos, false)
	tiles.clear()
