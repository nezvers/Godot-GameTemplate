## Collects tiles for obstacles and puts information into AStarGrid2D for navigation path calculations
class_name TileNavigationBlocking
extends Node

## TileMapLayer for creating obstacle tiles
@export var tilemap_layer:TileMapLayer
@export var astargrid_resource:AstarGridResource

## TODO: use data in tile_set for weight informtion

func _ready()-> void:
	assert(astargrid_resource != null)
	astargrid_resource.updated.connect(setup_obstacles)
	setup_obstacles()


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
	for _pos:Vector2i in _tiles:
		_astar.set_point_solid(_pos, true)

## Free obstacles from NavigationServer
func _exit_tree() -> void:
	if astargrid_resource.value == null:
		return
	
