class_name AstarGridResource
extends ValueResource

signal cleanup_event

@export var default_compute_heuristic:AStarGrid2D.Heuristic
@export var default_estimate_heuristic:AStarGrid2D.Heuristic
@export var diagonal_mode:AStarGrid2D.DiagonalMode
@export var jumping_enabled:bool

var value:AStarGrid2D
var tilemap_layer:TileMapLayer

func set_value(_value:AStarGrid2D)->void:
	value = _value
	if value != null:
		value.default_compute_heuristic = default_compute_heuristic
		value.default_estimate_heuristic = default_estimate_heuristic
		value.diagonal_mode = diagonal_mode
		value.jumping_enabled = jumping_enabled
		value.update()
	updated.emit()

func cleanup()->void:
	value = null
	tilemap_layer = null
	cleanup_event.emit()
