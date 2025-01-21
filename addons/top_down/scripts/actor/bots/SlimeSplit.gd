class_name SlimeSplit
extends Node

@export var resource_node:ResourceNode

@export var split_instance_resource:InstanceResource

@export var angles:Array[float] = [-25.0, 25.0, -65.0, 65.0 ]

@export var spawn_distance:float = 8.0

@export var axis_multiplication:Vector2Resource

@export var position_node:Node2D

@export var active_enemy:ActiveEnemy

func _ready() -> void:
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	_damage_resource.received_damage.connect(_on_damage_received)
	
	# for use with PoolNode
	tree_exiting.connect(_damage_resource.received_damage.disconnect.bind(_on_damage_received), CONNECT_ONE_SHOT)
	request_ready()

func _on_damage_received(damage:DamageDataResource)->void:
	if !damage.is_kill:
		return
	
	var _active_enemy_branch:Dictionary = active_enemy.my_dictionary
	# count itself out
	_active_enemy_branch.count -= 1
	
	var _direction:Vector2 = damage.direction
	var _pos:Vector2 = position_node.global_position
	
	for _degree:float in angles:
		var _config_callback:Callable = func (inst:Node)->void:
			var _dir:Vector2 = (_direction.rotated(deg_to_rad(_degree)) * axis_multiplication.value).normalized()
			inst.global_position = _pos + spawn_distance * _dir
			
			# increase own count for each child branch
			_active_enemy_branch.count += 1
			ActiveEnemy.insert_child(inst, _active_enemy_branch)
		
		split_instance_resource.instance(_config_callback)
