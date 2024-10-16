class_name ResetHealth
extends Node

@export var resource_node:ResourceNode

func _ready()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	_health_resource.reset_resource()
