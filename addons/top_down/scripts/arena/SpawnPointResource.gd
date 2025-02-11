class_name SpawnPointResource
extends SaveableResource

@export var position_list:Array[Vector2]

@export var boss_position_list:Array[Vector2]

func add_position(position:Vector2)->void:
	position_list.append(position)

func add_boss_position(position:Vector2)->void:
	boss_position_list.append(position)
