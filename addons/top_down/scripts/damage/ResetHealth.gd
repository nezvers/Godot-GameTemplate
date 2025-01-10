class_name ResetHealth
extends Node

@export var resource_node:ResourceNode

## Player's health is globally used and stays the same
func _ready()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	_health_resource.reset_resource()
	
	_health_resource.dead.connect(owner.queue_free)
