class_name ScoreResource
extends SaveableResource

signal updated

@export var value:int = 0

func reset_resource()->void:
	value = 0

func add_point()->void:
	value += 1
	updated.emit()
