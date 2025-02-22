class_name DropManager
extends Node

@export var enemy_spawner:EnemySpawner

@export var coin_instance:InstanceResource

@export var health_pickup_instance:InstanceResource

@export var luck_resource:FloatResource

@export var drop_chance:float = 0.3

func _ready()->void:
	enemy_spawner.enemy_killed.connect(_on_killed)

func _on_killed(enemy:ActiveEnemy)->void:
	var _position:Vector2 = enemy.owner.global_position
	
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _position
	
	coin_instance.instance(_config_callback)
	
	var _rand:float = randf_range(0.0, 1.0)
	if _rand > drop_chance:
		return
	health_pickup_instance.instance(_config_callback)
