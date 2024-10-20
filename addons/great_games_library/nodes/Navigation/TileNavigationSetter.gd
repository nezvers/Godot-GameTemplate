class_name TileNavigationSetter
extends Node

@export var tilemap_layer:TileMapLayer
@export var astargrid_resource:AstarGridResource
## set bigger AStar region on each side
@export var grow_region:int = 1

func _ready()->void:
	assert(tilemap_layer != null)
	assert(astargrid_resource != null)
	initialize_astargrid()


func initialize_astargrid()->void:
	if astargrid_resource.value != null:
		# already initialized
		return
	
	astargrid_resource.tilemap_layer = tilemap_layer
	
	var _tile_rect:Rect2i = tilemap_layer.get_used_rect()
	_tile_rect = _tile_rect.grow(grow_region)
	
	var _astar:AStarGrid2D = AStarGrid2D.new()
	_astar.region = _tile_rect
	var _tileset:TileSet = tilemap_layer.tile_set
	_astar.cell_size = _tileset.tile_size
	_astar.offset = Vector2.ZERO
	
	if _tileset.tile_shape == TileSet.TileShape.TILE_SHAPE_SQUARE:
		_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_SQUARE
	if _tileset.tile_shape == TileSet.TileShape.TILE_SHAPE_ISOMETRIC:
		if _tileset.tile_layout == TileSet.TileLayout.TILE_LAYOUT_DIAMOND_RIGHT:
			_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_ISOMETRIC_RIGHT
		if _tileset.tile_layout == TileSet.TileLayout.TILE_LAYOUT_DIAMOND_DOWN:
			_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_ISOMETRIC_DOWN
	
	astargrid_resource.set_value(_astar)
	tree_exiting.connect(astargrid_resource.cleanup)
