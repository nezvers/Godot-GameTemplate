class_name TileNavigationSetter
extends Node

@export var tilemap_layer:TileMapLayer
@export var astargrid_resource:AstarGridResource
@export var default_compute_heuristic:AStarGrid2D.Heuristic
@export var default_estimate_heuristic:AStarGrid2D.Heuristic
@export var diagonal_mode:AStarGrid2D.DiagonalMode
@export var jumping_enabled:bool

func _ready()->void:
	assert(tilemap_layer != null)
	assert(astargrid_resource != null)
	initialize_astargrid()


func initialize_astargrid()->void:
	if astargrid_resource.value != null:
		# already initialized
		return
	
	astargrid_resource.tilemap_layer = tilemap_layer
	
	var _astar:AStarGrid2D = AStarGrid2D.new()
	_astar.default_compute_heuristic = default_compute_heuristic
	_astar.default_estimate_heuristic = default_estimate_heuristic
	_astar.diagonal_mode = diagonal_mode
	_astar.jumping_enabled = jumping_enabled
	
	_astar.region = tilemap_layer.get_used_rect()
	var _tileset:TileSet = tilemap_layer.tile_set
	_astar.cell_size = _tileset.tile_size
	_astar.offset = Vector2.ZERO#_tileset.tile_size * 0.5
	
	if _tileset.tile_shape == TileSet.TileShape.TILE_SHAPE_SQUARE:
		_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_SQUARE
	if _tileset.tile_shape == TileSet.TileShape.TILE_SHAPE_ISOMETRIC:
		if _tileset.tile_layout == TileSet.TileLayout.TILE_LAYOUT_DIAMOND_RIGHT:
			_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_ISOMETRIC_RIGHT
		if _tileset.tile_layout == TileSet.TileLayout.TILE_LAYOUT_DIAMOND_DOWN:
			_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_ISOMETRIC_DOWN
	
	_astar.update()
	astargrid_resource.set_value(_astar)
