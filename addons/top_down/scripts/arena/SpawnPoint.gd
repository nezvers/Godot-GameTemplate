class_name SpawnPoint
extends Marker2D

const resource_path:String = "res://addons/top_down/resources/arena_resources/spawn_point_resource.tres"

@export var boss_position:bool

func _ready()->void:
	var _spawn_point_resource:SpawnPointResource = load(resource_path)
	if !boss_position:
		_spawn_point_resource.add_position(global_position)
	else:
		_spawn_point_resource.add_boss_position(global_position)
