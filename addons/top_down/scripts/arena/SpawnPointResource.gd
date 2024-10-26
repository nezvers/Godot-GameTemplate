class_name SpawnPointResource
extends SaveableResource

@export var position_list:Array[Vector2]

func add_position(position:Vector2)->void:
	position_list.append(position)
