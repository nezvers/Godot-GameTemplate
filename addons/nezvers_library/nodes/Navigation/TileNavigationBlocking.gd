## Collects tiles for obstacles and puts information into AStarGrid2D for navigation path calculations
class_name TileNavigationBlocking
extends Node

## TileMapLayer for creating obstacle tiles
@export var tilemap_layer:TileMapLayer
@export var astargrid_resource:AstarGridResource
@export var obstacle_shape:Shape2D
@export_flags_2d_physics var collision_layer:int
@export_flags_2d_physics var collision_mask:int

## TODO: use data in tile_set for navigation weight informtion

var collider_rid_list:Array[RID]

func _ready()-> void:
	assert(astargrid_resource != null)
	astargrid_resource.updated.connect(setup_obstacles)
	setup_obstacles()
	tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)


func setup_obstacles()->void:
	if astargrid_resource.value == null:
		return
	var _tilemap_rect:Rect2i = tilemap_layer.get_used_rect()
	var _astar_rect:Rect2i = astargrid_resource.value.region
	var _astar:AStarGrid2D = astargrid_resource.value
	
	# Left side
	if  _tilemap_rect.position.x < _astar_rect.position.x:
		_astar.region.position.x = _tilemap_rect.position.x
	# Top side
	if  _tilemap_rect.position.y < _astar_rect.position.y:
		_astar.region.position.y = _tilemap_rect.position.y
	# Right side
	if  _tilemap_rect.position.x + _tilemap_rect.size.x > _astar_rect.position.x + _astar_rect.size.x:
		_astar.region.size.x = _tilemap_rect.position.x + _tilemap_rect.size.x - _astar_rect.position.x 
	# Bottom side
	if  _tilemap_rect.position.y + _tilemap_rect.size.y > _astar_rect.position.y + _astar_rect.size.y:
		_astar.region.size.y = _tilemap_rect.position.y + _tilemap_rect.size.y - _astar_rect.position.y 
	
	var _tiles:Array[Vector2i] = tilemap_layer.get_used_cells()
	collider_rid_list.resize(_tiles.size())
	var _space:RID = tilemap_layer.get_world_2d().space
	var _id:int = get_instance_id()
	var _body_mode:PhysicsServer2D.BodyMode = PhysicsServer2D.BODY_MODE_KINEMATIC
	
	for i:int in _tiles.size():
		var _tile_pos:Vector2i = _tiles[i]
		_astar.set_point_solid(_tile_pos, true)
		
		# TODO: create a collider
		var _pos:Vector2 = tilemap_layer.map_to_local(_tile_pos)
		var _transform:Transform2D = Transform2D(0.0, _pos)
		var _body_rid:RID = PhysicsHelper.body_create_2d(_space, collision_layer, collision_mask, obstacle_shape, _transform, _body_mode, _id)
		collider_rid_list[i] = _body_rid


## Free obstacles from AstarGrid & PhysicsServer
func cleanup() -> void:
	if astargrid_resource.value == null:
		return
	var _tiles:Array[Vector2i] = tilemap_layer.get_used_cells()
	
	for i:int in _tiles.size():
		var _tile_pos:Vector2i = _tiles[i]
		astargrid_resource.value.set_point_solid(_tile_pos, false)
	
	for _body_rid:RID in collider_rid_list:
		PhysicsServer2D.free_rid(_body_rid)
