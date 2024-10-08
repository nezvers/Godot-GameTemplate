class_name AstarGridResource
extends ValueResource

var value:AStarGrid2D

func set_value(_value:AStarGrid2D)->void:
	value = _value
	updated.emit()
