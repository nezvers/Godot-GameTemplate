class_name EnemySpawner
extends Node

signal enemy_killed(enemy:ActiveEnemy)

@export var enemy_manager:EnemyManager

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


## Maximum simultaneous enemies
## TODO: influence with difficulity
var max_allowed_count:int


func _ready()->void:
	assert(enemy_count_resource != null)
	assert(spawn_point_resource != null)
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

func _cleanup()->void:
	spawn_point_resource.position_list.clear()
	spawn_point_resource.boss_position_list.clear()
	ActiveEnemy.root = ActiveEnemyResource.new()

## Decide if new enemy needs to be created.
## Don't like idea of _process, but is continiously check when spawnpoint is safe to use
func _process(_delta: float) -> void:
	var _active_count:int = ActiveEnemy.root.nodes.size() + ActiveEnemy.root.children.size()
	
	if max_allowed_count - _active_count < 1:
		return
	if _active_count >= max_allowed_count:
		return
	
	## One more shouldn't be more than left to kill
	if _active_count +1 > enemy_count_resource.value:
		return
	
	_create_spawn_mark()

func _create_spawn_mark()->void:
	if enemy_manager.wave_queue.waves.is_empty():
		return
	
	var _current_wave:SpawnWaveList = enemy_manager.wave_queue.waves.front()
	
	var _free_positions:Array[Vector2]
	if _current_wave.is_boss:
		_free_positions = spawn_point_resource.boss_position_list.filter(_filter_free_position)
		#_create_enemies(_free_positions.pick_random())
		#return
	else:
		_free_positions = spawn_point_resource.position_list.filter(_filter_free_position)
	if _free_positions.is_empty():
		return
	
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
		ActiveEnemy.insert_child(inst, ActiveEnemy.root, _erase_enemy)
	
	enemy_manager.wave_queue.waves.front().instance_list.pick_random().instance(_enemy_config)

func _erase_enemy(enemy:ActiveEnemy)->void:
	enemy_count_resource.set_value(enemy_count_resource.value -1)
	enemy_killed.emit(enemy)

func _filter_free_position(position:Vector2)->bool:
	# distance squared
	const FREE_DISTANCE:float = 116.0 * 116.0
	
	var _closest_dist:float = 999999.0
	## Actual enemy instances
	var instance_list:Array[Node2D] = ActiveEnemy.active_instances
	for inst:Node2D in instance_list:
		assert(inst != null)
		# for finding closest length_squared is great, since it is faster without using square root.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist
	
	# free distance was squared because it is compared againsts length_squared
	return _closest_dist > FREE_DISTANCE

func _config_spawn_mark(inst:Node2D, spawn_position:Vector2)->void:
	inst.global_position = spawn_position
	inst.tree_exiting.connect(_create_enemies.bind(spawn_position), CONNECT_ONE_SHOT)

func _config_spawn_particles(inst:Node2D, spawn_position:Vector2)->void:
	inst.global_position = spawn_position
