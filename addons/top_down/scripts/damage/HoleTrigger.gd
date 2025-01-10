class_name HoleTrigger
extends Node

signal hole_touched

@export var resource_node:ResourceNode

func _ready()->void:
	var _hole_bool:BoolResource = resource_node.get_resource("hole")
	assert(_hole_bool != null)
	_hole_bool.updated.connect(_on_hole_updated.bind(_hole_bool))
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(_hole_bool.updated.disconnect.bind(_on_hole_updated), CONNECT_ONE_SHOT)


func _on_hole_updated(hole_bool:BoolResource)->void:
	if hole_bool.value == false:
		return
	hole_touched.emit()
	hole_bool.set_value(false)
