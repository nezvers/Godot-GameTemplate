class_name ItemDrop
extends Node

@export var resource_node:ResourceNode
@export var root_node:Node2D
@export var drop_instance_resources:Array[InstanceResource]
@export var drop_chance:float = 0.1

func _ready()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	assert(_health_resource != null)
	_health_resource.dead.connect(_on_death)
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(_health_resource.dead.disconnect.bind(_on_death), CONNECT_ONE_SHOT)

func _on_death()->void:
	if drop_instance_resources.is_empty():
		return
	if randf() > drop_chance:
		return
	
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = root_node.global_position
	
	var _drop_instance_resource:InstanceResource = drop_instance_resources.pick_random()
	_drop_instance_resource.instance(_config_callback)
