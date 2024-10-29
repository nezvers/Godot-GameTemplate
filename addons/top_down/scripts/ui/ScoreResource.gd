class_name ScoreResource
extends SaveableResource

signal points_updated

@export var point_count:int = 0

func reset_resource()->void:
	point_count = 0

func add_point()->void:
	point_count += 1
	points_updated.emit()
