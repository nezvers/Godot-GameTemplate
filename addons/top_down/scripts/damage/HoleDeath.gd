class_name HoleDeath
extends Node

@export var enabled:bool = true

@export var hole_trigger:HoleTrigger

@export var resource_node:ResourceNode

func _ready()->void:
	if !enabled:
		return
	
	
	# TODO: Create more pleasant hole falling death
	hole_trigger.hole_touched.connect(_insta_kill)
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(hole_trigger.hole_touched.disconnect.bind(_insta_kill), CONNECT_ONE_SHOT)

func _insta_kill()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	assert(_health_resource != null)
	var _hp:float = _health_resource.hp
	_health_resource.insta_kill()
	
	var _damage_data:DamageDataResource = DamageDataResource.new("damage")
	_damage_data.total_damage = _hp
	_damage_data.is_kill = true
	var _damage:DamageResource = resource_node.get_resource("damage")
	_damage.receive(_damage_data)
