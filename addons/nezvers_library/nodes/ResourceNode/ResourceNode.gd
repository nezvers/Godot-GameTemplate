## Node to hold resources in a dictionary
class_name ResourceNode
extends Node

## Emitted when dictionary is changed through add / remove functions
signal updated

@export var list:Array[ResourceNodeItem]

## Cache items to retrieve them with a key
var dictionary:Dictionary

func _ready()->void:
	for item:ResourceNodeItem in list:
		assert(!item.resource_name.is_empty(), "resource_name is used as a key for a dictionary")
		assert(item.resource != null)
		item = item.duplicate()
		if item.make_unique:
			item.value = item.resource.duplicate()
		else:
			item.value = item.resource
		dictionary[item.resource_name] = item

## Adds a resource item and saves into a dictionary
func add_resource(item:ResourceNodeItem)->void:
	assert(!item.resource_name.is_empty(), "resource_name is used as a key for a dictionary")
	assert(item.resource != null)
	if item.make_unique:
		item.value = item.resource.duplicate()
	else:
		item.value = item.resource
	list.append(item)
	dictionary[item.resource_name] = item
	updated.emit()

## Removes resource reference
func remove_resource(key:String)->void:
	if !dictionary.has(key):
		return
	var item:ResourceNodeItem = dictionary[key]
	list.erase(item)
	dictionary.erase(key)
	updated.emit()

## If key doesn't exists `null` is returned
func get_resource(key:String)->SaveableResource:
	if !dictionary.has(key):
		return null
	return dictionary[key].value
