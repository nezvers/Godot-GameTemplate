class_name DropManager
extends Node

## Arena sections whose enemy kills drop loot.
@export var sections:Array[ArenaSection]

@export var coin_instance:InstanceResource

@export var health_pickup_instance:InstanceResource

@export var meat_instance:InstanceResource

@export var slime_instance:InstanceResource

@export var luck_resource:FloatResource

@export var drop_chance:float = 0.3

@export var meat_chance:float = 0.4

@export var slime_chance:float = 0.1

func _ready()->void:
	for _section:ArenaSection in sections:
		if _section == null:
			continue
		_section.enemy_killed.connect(_on_killed)

func _on_killed(enemy:ActiveEnemy)->void:
	var _position:Vector2 = enemy.owner.global_position
	
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _position
	
	coin_instance.instance(_config_callback)
	
	# Each loot type rolls on its own
	_roll(health_pickup_instance, drop_chance, _config_callback)
	_roll(meat_instance, meat_chance, _config_callback)
	_roll(slime_instance, slime_chance, _config_callback)

func _roll(instance_resource:InstanceResource, chance:float, config_callback:Callable)->void:
	if instance_resource == null:
		return
	if randf() > chance:
		return
	instance_resource.instance(config_callback)
