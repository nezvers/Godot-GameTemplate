class_name BigJellySlimeSpawner
extends Node

static var active_enemy_branch:ActiveEnemyResource

@export var projectile:Projectile2D

@export var instance_resource:InstanceResource

@export var angles:Array[float]

@export var spawn_distance:float = 8.0

@export var axis_multiplication:Vector2Resource

func _ready()->void:
	projectile.prepare_exit_event.connect(_on_prepare_exit)

func _on_prepare_exit()->void:
	var _direction:Vector2 = projectile.direction
	var _pos:Vector2 = projectile.global_position
	
	for _degree:float in angles:
		var _config_callback:Callable = func (inst:Node)->void:
			var _dir:Vector2 = (_direction.rotated(deg_to_rad(_degree)) * axis_multiplication.value).normalized()
			inst.global_position = _pos + spawn_distance * _dir
			
			ActiveEnemy.insert_child(inst, active_enemy_branch)
		
		instance_resource.instance(_config_callback)
