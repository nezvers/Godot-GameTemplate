class_name AstarGridResource
extends ValueResource

@export var default_compute_heuristic:AStarGrid2D.Heuristic
@export var default_estimate_heuristic:AStarGrid2D.Heuristic
@export var diagonal_mode:AStarGrid2D.DiagonalMode
@export var jumping_enabled:bool

var value:AStarGrid2D
var tilemap_layer:TileMapLayer

func set_value(_value:AStarGrid2D)->void:
	value = _value
	if value != null:
		default_compute_heuristic = default_compute_heuristic
		default_estimate_heuristic = default_estimate_heuristic
		diagonal_mode = diagonal_mode
		jumping_enabled = jumping_enabled
	updated.emit()
