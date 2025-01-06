class_name BootPreloader
extends Node2D

signal preload_finished

@export var preload_resource:PreloadResource

## Designated node to hold nodes for material compilation
@export var material_holder_node:Node

var saveable_resources_done:bool
var preload_resource_done:bool


func _set_saveable_resources_done(value:bool)->void:
	saveable_resources_done = value
	print("BootPreloader [INFO]: SaveableResources - DONE")
	_check_done()

func _set_preload_resource_done_done(value:bool)->void:
	preload_resource_done = value
	print("BootPreloader [INFO]: SaveableResources - DONE")
	_check_done()

func _check_done()->void:
	if !preload_resource_done:
		return
	if !saveable_resources_done:
		return
	preload_finished.emit()

## Combination of single thread Node loading with multithread on PreloadResource
func start()->void:
	preload_resource.preload_finished.connect(_set_preload_resource_done_done.bind(true), CONNECT_ONE_SHOT)
	preload_resource.start(material_holder_node)
	# Hold in memory
	PersistentData.data["preload_resource"] = preload_resource
	
	# preload savables
	for saveable:SaveableResource in PersistentData.saveable_list:
		saveable.load_resource()
	_set_saveable_resources_done(true)
