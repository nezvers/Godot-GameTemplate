extends Node

@export var fight_mode_resource:BoolResource
@export var wave_count_resource:IntResource
@export var enemy_count_resource:IntResource
@export var enemy_manager:EnemyManager

func _ready()->void:
	assert(fight_mode_resource != null)
	assert(wave_count_resource != null)
	assert(enemy_count_resource != null)
	
	fight_mode_resource.changed_true.connect(_on_fight_mode_true) # Setup 1
	wave_count_resource.updated.connect(_on_wave_count_changed) # Setup 2
	enemy_count_resource.updated.connect(_on_enemy_count_changed) # Setup 3

# Setup 1
func _on_fight_mode_true()->void:
	wave_count_resource.set_value(enemy_manager.wave_setup.size())

# Setup 2
func _on_wave_count_changed()->void:
	if wave_count_resource.value == 0:
		fight_mode_resource.set_value(false)
		return
	
	# TODO: have some rule of enemy count & strength spawning
	enemy_count_resource.set_value(enemy_manager.wave_setup.pop_front())

# Setup 3
func _on_enemy_count_changed()->void:
	if fight_mode_resource.value == false:
		return
	if wave_count_resource.value == 0:
		return
	if enemy_count_resource.value > 0:
		return
	
	wave_count_resource.set_value(wave_count_resource.value - 1)
