extends Node

@export var instance_resource_list:Array[InstanceResource]
@export var action_resource:ActionResource

var is_preloaded:bool

func _set_is_preloaded(value:bool)->void:
	is_preloaded = value
	print("PersistentData [INFO]: data are preloaded")

func _ready() -> void:
	action_resource.initialize()
	# Just in case use same thread for loading all scenes
	var _scene_list:Array[Dictionary]
	for _instance_resource in instance_resource_list:
		var _data:Dictionary = {path = _instance_resource.scene_path, callback = _instance_resource.set_scene}
		_scene_list.append(_data)
		#_instance_resource.preload_scene()
	ThreadUtility.load_resource_list(_scene_list, _set_is_preloaded.bind(true))
