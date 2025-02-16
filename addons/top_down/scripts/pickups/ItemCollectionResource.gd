class_name ItemCollectionResource
extends SaveableResource

signal updated
signal removed(value:ItemResource)
signal selected_changed

@export var list:Array[ItemResource]

@export var selected:int

@export var max_items:int

func set_list(value:Array[ItemResource])->void:
	list = value
	updated.emit()

func set_selected(value:int)->void:
	if list.is_empty():
		selected = 0
	else:
		selected = abs(value + list.size()) % list.size()
	selected_changed.emit()

func append(value:ItemResource)->void:
	list.append(value)
	updated.emit()

func swap(value:ItemResource)->ItemResource:
	var _item:ItemResource = list[selected]
	list[selected] = value
	updated.emit()
	removed.emit(_item)
	return _item

func drop()->ItemResource:
	var _item:ItemResource = list[selected]
	list[selected] = null
	removed.emit(_item)
	
	list = list.filter(filter_empty)
	set_selected(max(selected, list.size()))
	
	updated.emit()
	removed.emit(_item)
	return _item

func filter_empty(value:ItemResource)->bool:
	return value != null
