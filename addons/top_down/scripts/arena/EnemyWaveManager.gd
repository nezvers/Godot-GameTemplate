extends Node

## Variable that toggles gameplay mode
@export var fight_mode_resource:BoolResource

@export var wave_count_resource:IntResource

## Current wave count, must kill count
@export var enemy_count_resource:IntResource

@export var enemy_manager:EnemyManager

func _ready()->void:
	assert(fight_mode_resource != null)
	assert(wave_count_resource != null)
	assert(enemy_count_resource != null)
	
	fight_mode_resource.changed_true.connect(_init_wave_count) # Setup 1
	wave_count_resource.updated.connect(_reset_enemy_count) # Setup 2
	enemy_count_resource.updated.connect(_update_wave_count) # Setup 3

func _exit_tree() -> void:
	fight_mode_resource.set_value(false)
	enemy_count_resource.set_value(0)
	wave_count_resource.set_value(0)

# Setup 1
func _init_wave_count()->void:
	wave_count_resource.set_value(enemy_manager.wave_queue.waves.size())

# Setup 2
func _reset_enemy_count()->void:
	if wave_count_resource.value == 0:
		fight_mode_resource.set_value(false)
		return
	
	var _wave_list:SpawnWaveList = enemy_manager.wave_queue.waves.front()
	var _enemy_count:int = _wave_list.count
	# TODO: have some rule of enemy count & strength spawning
	enemy_count_resource.set_value(_enemy_count)

# Setup 3
func _update_wave_count()->void:
	if fight_mode_resource.value == false:
		return
	if wave_count_resource.value == 0:
		return
	if enemy_count_resource.value > 0:
		return
	
	enemy_manager.wave_queue.waves.pop_front()
	wave_count_resource.set_value(enemy_manager.wave_queue.waves.size())
