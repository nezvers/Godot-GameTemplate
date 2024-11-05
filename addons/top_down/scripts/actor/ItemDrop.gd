class_name ItemDrop
extends Node

@export var root_node:Node2D
@export var drop_parent_reference:ReferenceNodeResource
@export var resource_node:ResourceNode
@export var drop_instance_resources:Array[InstanceResource]
@export var drop_chance:float = 0.1

func _ready()->void:
	assert(drop_parent_reference != null)
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	assert(_health_resource != null)
	_health_resource.dead.connect(on_death)

func on_death()->void:
	if drop_instance_resources.is_empty():
		return
	if randf() > drop_chance:
		return
	
	var _drop_instance_resource:InstanceResource = drop_instance_resources.pick_random()
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = root_node.global_position
	_drop_instance_resource.instance(_config_callback)
