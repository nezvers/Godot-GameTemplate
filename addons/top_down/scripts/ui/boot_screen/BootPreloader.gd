class_name BootPreloader
extends Node2D

signal preload_finished

var instance_resources_done:bool
var saveable_resources_done:bool
var shaders_done:bool

func _set_instance_resources_done(value:bool)->void:
	instance_resources_done = value
	print("BootPreloader [INFO]: instance resources - DONE")
	_check_done()

func _set_saveable_resources_done(value:bool)->void:
	saveable_resources_done = value
	print("BootPreloader [INFO]: SaveableResources - DONE")
	_check_done()

func _set_shaders_done(value:bool)->void:
	shaders_done = value
	print("BootPreloader [INFO]: Shaders - DONE")
	_check_done()

func _check_done()->void:
	if !instance_resources_done:
		return
	if !saveable_resources_done:
		return
	# TODO: add shader preload
	#if !shaders_done:
		#return
	preload_finished.emit()


func start()->void:
	# preload InstanceResoource scenes
	# Just in case use same thread for loading all scenes
	var _scene_list:Array[Dictionary]
	for _instance_resource in PersistentData.instance_resource_list:
		var _data:Dictionary = {path = _instance_resource.scene_path, callback = _instance_resource.set_scene}
		_scene_list.append(_data)
	ThreadUtility.load_resource_list(_scene_list, _set_instance_resources_done.bind(true))
	
	# preload savables
	for saveable:SaveableResource in PersistentData.saveable_list:
		saveable.load_resource()
	_set_saveable_resources_done(true)
	
	# TODO: Precompile shaders
