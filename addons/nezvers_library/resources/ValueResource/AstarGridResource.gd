class_name AstarGridResource
extends ValueResource

var value:AStarGrid2D
var tilemap_layer:TileMapLayer

func set_value(_value:AStarGrid2D)->void:
	value = _value
	updated.emit()
