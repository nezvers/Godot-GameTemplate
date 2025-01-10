class_name HoleDeath
extends Node

@export var enabled:bool = true

@export var hole_trigger:HoleTrigger

@export var resource_node:ResourceNode

func _ready()->void:
	if !enabled:
		return
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	assert(_health_resource != null)
	
	# TODO: Create more pleasant hole falling death
	hole_trigger.hole_touched.connect(_health_resource.insta_kill)
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(hole_trigger.hole_touched.disconnect.bind(_health_resource.insta_kill), CONNECT_ONE_SHOT)
