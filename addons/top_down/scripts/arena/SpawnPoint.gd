class_name SpawnPoint
extends Marker2D

const resource_path:String = "res://addons/top_down/resources/arena_resources/spawn_point_resource.tres"

func _ready()->void:
	var _spawn_point_resource:SpawnPointResource = load(resource_path)
	_spawn_point_resource.add_position(global_position)
