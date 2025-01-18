class_name CriticalDamageReplace
extends Node

@export var resource_node:ResourceNode

@export var pool_node:PoolNode

## Getting critical damage bellow treshold will replace with different instance
@export var health_treshold:float = 20.0

## Instance resource for replacement on critical hit below health treshold
@export var replacement_instance_resource:InstanceResource

var health_resource:HealthResource

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	assert(health_resource != null)
	
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	assert(_damage_resource != null)
	# points signal is after received_damage, means a kickback is already calculated and can be passed to replacement
	_damage_resource.received_damage.connect(_on_damage)
	
	# When used with PoolNode
	request_ready()
	# in case it is a persistent resource
	tree_exiting.connect(_damage_resource.received_damage.disconnect.bind(_on_damage), CONNECT_ONE_SHOT)

func _on_damage(damage:DamageDataResource)->void:
	if !damage.is_critical:
		return
	
	if health_resource.is_dead:
		return
	
	if health_resource.hp > health_treshold:
		return
	
	var _push_vector:Vector2 = damage.kickback_strength * damage.direction
	
	## applied to instance when its ready
	var _ready_callback:Callable = func (inst:Node, resource_node:ResourceNode)->void:
		var _push_resource:PushResource = resource_node.get_resource("push")
		_push_resource.add_impulse(_push_vector)
	
	var _config_callback:Callable = func (inst:Node)->void:
		inst.global_position = owner.global_position
		
		var _resource_node:ResourceNode = inst.get_node("ResourceNode")
		for item:ResourceNodeItem in _resource_node.list:
			if !(item.resource is HealthResource):
				continue
			## need to replace HealthResource before ready
			item.resource = health_resource
		
		inst.ready.connect(_ready_callback.bind(inst, _resource_node), CONNECT_ONE_SHOT)
	
	replacement_instance_resource.instance(_config_callback)
	pool_node.pool_return()
