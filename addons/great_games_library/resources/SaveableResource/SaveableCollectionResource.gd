class_name SaveableCollectionResource
extends SaveableResource

## A list of all things that is savable with this resource
## Requires to have a resource_name - used for dictionary lookup
@export var save_list:Array[SaveableResource]


var name_dictionary:Dictionary
var is_initialized:bool

## Reset dictionary to default
func reset_resource()->void:
	if is_initialized:
		return
	name_dictionary.clear()
	for item in save_list:
		name_dictionary[item.resource_name] = item
	is_initialized = true

## Override for creating data Resource that will be saved with the ResourceSaver
func prepare_save()->Resource:
	var data:SaveableCollectionResource = self.duplicate()
	data.save_list.clear()
	for i in data.save_list.size():
		data.save_list.append(data.save_list[i].prepare_save())
	return data

## Override to ad logic for reading loaded data and applying to current instance of the Resource
func prepare_load(_data:Resource)->void:
	reset_resource()
	var data:SaveableCollectionResource = _data
	for item in data.save_list:
		if !name_dictionary.has(item.resource_name):
			continue
		name_dictionary[item.resource_name].prepare_load(item)
