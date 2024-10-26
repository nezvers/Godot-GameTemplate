class_name EnemySpawner
extends Node

@export var enemy_instance_resource:InstanceResource
@export var enemy_count_resource:IntResource
@export var spawn_point_resource:SpawnPointResource
@export var fight_mode_resource:BoolResource

var max_active_count:int
var allowed_count:int

func _ready()->void:
	assert(enemy_count_resource != null)
	assert(spawn_point_resource != null)
	assert(enemy_instance_resource != null)
	assert(fight_mode_resource != null)
	
	fight_mode_resource.changed_true.connect(set_process.bind(true))
	fight_mode_resource.changed_false.connect(set_process.bind(false))
	set_process(fight_mode_resource.value)
	tree_exiting.connect(cleanup)
	
	setup_active_count.call_deferred()

func setup_active_count()->void:
	max_active_count = spawn_point_resource.position_list.size()
	allowed_count = max_active_count

func cleanup()->void:
	spawn_point_resource.position_list.clear()

func _process(delta: float) -> void:
	if enemy_count_resource.value < max_active_count:
		return
	if allowed_count < 1:
		return
	if enemy_instance_resource.instance_list.size() >= max_active_count:
		return
	
	_create_enemy()

func _create_enemy()->void:
	var _free_positions:Array[Vector2] = spawn_point_resource.position_list.filter(_filter_free_position)
	if _free_positions.is_empty():
		return
	
	var _inst:Node2D = enemy_instance_resource.instance_2d(_free_positions.pick_random())
	_inst.tree_exiting.connect(_erase_enemy.bind(_inst))
	allowed_count -= 1

func _erase_enemy(node:Node2D)->void:
	enemy_count_resource.set_value(enemy_count_resource.value -1)
	allowed_count += 1

func _filter_free_position(position:Vector2)->bool:
	# distance squared
	const FREE_DISTANCE:float = 10.0 * 10.0
	
	var _closest_dist:float = 999999.0
	for inst:Node2D in enemy_instance_resource.instance_list:
		# for finding closest length_squared is great, since it is faster without using square root.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist
	
	# free distance was squared because it is compared againsts length_squared
	return _closest_dist > FREE_DISTANCE
