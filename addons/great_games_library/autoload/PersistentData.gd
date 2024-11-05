extends Node

@export var instance_resource_list:Array[InstanceResource]

func _ready() -> void:
	for _instance_resource in instance_resource_list:
		_instance_resource.preload_scene()
