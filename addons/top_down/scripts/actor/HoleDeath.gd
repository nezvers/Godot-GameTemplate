class_name HoleDeath
extends Node

@export var resource_node:ResourceNode

func _ready()->void:
	var _hole_bool:BoolResource = resource_node.get_resource("hole")
	assert(_hole_bool != null)
	
	_hole_bool.updated.connect(_on_hole_updated.bind(_hole_bool))

func _on_hole_updated(hole_bool:BoolResource)->void:
	if hole_bool.value == false:
		return
	# TODO: implement more immersive falling death
	var _health_resource:HealthResource = resource_node.get_resource("health")
	assert(_health_resource != null)
	_health_resource.add_hp( -_health_resource.hp)
