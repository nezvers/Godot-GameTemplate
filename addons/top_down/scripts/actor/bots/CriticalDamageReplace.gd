class_name CriticalDamageReplace
extends Node

@export var resource_node:ResourceNode

@export var pool_node:PoolNode

@export var active_enemy:ActiveEnemy

## Getting critical damage bellow treshold will replace with different instance
@export var health_treshold:float = 20.0

## Instance resource for replacement on critical hit below health treshold
@export var replacement_instance_resource:InstanceResource

@export var sound_effect:SoundResource

@export var damage_data_receiver:DataChannelReceiver

var health_resource:HealthResource

## Due to physics having multiple collisions, this is used to trigger once
var is_replaced:bool

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	assert(health_resource != null)
	
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	assert(_damage_resource != null)
	# points signal is after received_damage, means a kickback is already calculated and can be passed to replacement
	_damage_resource.received_damage.connect(_on_damage)
	
	# When used with PoolNode
	request_ready()
	is_replaced = false
	damage_data_receiver.enabled = true
	# in case it is a persistent resource
	tree_exiting.connect(_damage_resource.received_damage.disconnect.bind(_on_damage), CONNECT_ONE_SHOT)

func _on_damage(damage:DamageDataResource)->void:
	if is_replaced:
		return
	
	if !damage.is_critical:
		return
	
	if health_resource.is_dead:
		return
	
	if health_resource.hp > health_treshold:
		return
	
	is_replaced = true
	damage_data_receiver.enabled = false
	# store necesary values into separate variables instead of keeping references to resources
	var _push_vector:Vector2 = damage.kickback_strength * damage.direction
	var _current_hp:float = health_resource.hp
	var _active_enemy_branch:Dictionary = active_enemy.my_dictionary
	
	# count it self out
	_active_enemy_branch.count -= 1
	
	## applied to instance when its ready
	var _ready_callback:Callable = func (inst:Node)->void:
		var _resource_node:ResourceNode = inst.get_node("ResourceNode")
		
		# make inst hp the same + triggers damage color flash
		var _health_resource:HealthResource = _resource_node.get_resource("health")
		_health_resource.add_hp.call_deferred(_current_hp - _health_resource.hp)
		
		var _push_resource:PushResource = resource_node.get_resource("push")
		_push_resource.add_impulse(_push_vector)
		
		# enable ready signal for next time
		inst.request_ready()
	
	var _config_callback:Callable = func (inst:Node)->void:
		inst.global_position = owner.global_position
		# WARNING: root node needs to request_ready() every time, either PoolNode or this callback
		inst.ready.connect(_ready_callback.call_deferred.bind(inst), CONNECT_ONE_SHOT)
		
		# increase own count for each child branch
		_active_enemy_branch.count += 1
		ActiveEnemy.insert_child(inst, _active_enemy_branch)
	
	
	sound_effect.play_managed()
	replacement_instance_resource.instance(_config_callback)
	pool_node.pool_return()
