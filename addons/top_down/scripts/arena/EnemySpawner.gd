class_name EnemySpawner
extends Node

## Creates enemies with given configuration 
@export var enemy_instance_resource:InstanceResource

## TODO: have an array of possible enemies and enemies mark selves as active in specialized resource
@export var enemy2_instance_resource:InstanceResource

## VFX before enemy appear
@export var spawn_mark_instance_resource:InstanceResource

## VFX on moment enemy spawns
@export var spawn_partickle_instance_resource:InstanceResource

## Current wave count, must kill count
@export var enemy_count_resource:IntResource

## List of points where enemy can be spawned
@export var spawn_point_resource:SpawnPointResource

## Bool that toggles game mode
@export var fight_mode_resource:BoolResource

## kill counter used to detect when an enemy or split is killed
## TODO: need specialized kill resource in case of multiple splits, passed down to generations
@export var score_resource:ScoreResource

## Maximum simultaneous enemies
var max_allowed_count:int

## Intermediate variable to take in account spawning VFX until a kill
var wave_active_count:int

func _ready()->void:
	assert(enemy_count_resource != null)
	assert(spawn_point_resource != null)
	assert(enemy_instance_resource != null)
	assert(spawn_mark_instance_resource != null)
	assert(fight_mode_resource != null)
	
	fight_mode_resource.changed_true.connect(set_process.bind(true))
	fight_mode_resource.changed_false.connect(set_process.bind(false))
	set_process(fight_mode_resource.value)
	tree_exiting.connect(_cleanup)
	
	_setup_active_count.call_deferred()

func _setup_active_count()->void:
	# TODO: best not to limit to spawn point count, maybe sum of enemy threat value
	max_allowed_count = spawn_point_resource.position_list.size()
	wave_active_count = max_allowed_count
	score_resource.points_updated.connect(_erase_enemy)

func _cleanup()->void:
	spawn_point_resource.position_list.clear()

## Decide if new enemy needs to be created.
## Don't like idea of _process, but is continiously check when spawnpoint is safe to use
func _process(_delta: float) -> void:
	#if enemy_count_resource.value < max_allowed_count: # TODO: tis fukd
		#return
	if wave_active_count < 1:
		return
	var _active_count:int = enemy_instance_resource.active_list.size() + spawn_mark_instance_resource.active_list.size() + enemy2_instance_resource.active_list.size()
	if _active_count >= max_allowed_count:
		return
	
	## One more shouldn't be more than left to kill
	if _active_count +1 > enemy_count_resource.value:
		return
	
	_create_spawn_mark()

func _create_spawn_mark()->void:
	var _free_positions:Array[Vector2] = spawn_point_resource.position_list.filter(_filter_free_position)
	if _free_positions.is_empty():
		return
	
	wave_active_count -= 1
	var _spawn_position:Vector2 = _free_positions.pick_random()
	
	## after despawning creates actual enemy
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _spawn_position
		inst.tree_exiting.connect(_create_enemies.bind(_spawn_position), CONNECT_ONE_SHOT)
	spawn_mark_instance_resource.instance(_config_callback)

func _create_enemies(spawn_position:Vector2)->void:
	var _partickle_config:Callable = func(inst:Node2D)->void:
		inst.global_position = spawn_position
	spawn_partickle_instance_resource.instance(_partickle_config)
	
	
	var _enemy_config:Callable = func (inst:Node2D)->void:
		inst.global_position = spawn_position
	
	enemy_instance_resource.instance(_enemy_config)

func _erase_enemy()->void:
	enemy_count_resource.set_value(enemy_count_resource.value -1)
	wave_active_count += 1

func _filter_free_position(position:Vector2)->bool:
	# distance squared
	const FREE_DISTANCE:float = 116.0 * 116.0
	
	var _closest_dist:float = 999999.0
	## Actual enemy instances
	## TODO: use a ressource with self subscribing active list
	for inst:Node2D in enemy_instance_resource.active_list:
		# for finding closest length_squared is great, since it is faster without using square root.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist
	
	for inst:Node2D in enemy2_instance_resource.active_list:
		# for finding closest length_squared is great, since it is faster without using square root.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist
	
	# Spawn markers
	for inst:Node2D in spawn_mark_instance_resource.active_list:
		# for finding closest length_squared is great, since it is faster without using square root.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist
	
	# free distance was squared because it is compared againsts length_squared
	return _closest_dist > FREE_DISTANCE
