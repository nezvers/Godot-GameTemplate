## Node to hold resources in a dictionary
class_name ResourceNode
extends Node

## Emitted when dictionary is changed through add / remove functions
signal updated

@export var list:Array[ResourceNodeItem]
var dictionary:Dictionary

func _ready()->void:
	for item:ResourceNodeItem in list:
		assert(!item.resource_name.is_empty(), "resource_name is used as a key for a dictionary")
		if item.make_unique:
			item.resource = item.resource.duplicate()
		dictionary[item.resource_name] = item

func add_resource(item:ResourceNodeItem)->void:
	assert(!item.resource_name.is_empty(), "resource_name is used as a key for a dictionary")
	if item.make_unique:
		item.resource = item.resource.duplicate()
	list.append(item)
	dictionary[item.resource_name] = item
	updated.emit()

func remove_resource(key:String)->void:
	if !dictionary.has(key):
		return
	var item:ResourceNodeItem = dictionary[key]
	list.erase(item)
	dictionary.erase(key)
	updated.emit()

func get_resource(key:String)->SaveableResource:
	assert(dictionary.has(key))
	if !dictionary.has(key):
		return null
	return dictionary[key].resource
