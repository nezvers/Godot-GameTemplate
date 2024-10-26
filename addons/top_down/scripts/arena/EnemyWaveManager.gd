extends Node

@export var fight_mode_resource:BoolResource
@export var wave_count_resource:IntResource
@export var enemy_count_resource:IntResource

func _ready()->void:
	assert(fight_mode_resource != null)
	assert(wave_count_resource != null)
	assert(enemy_count_resource != null)
	
	fight_mode_resource.changed_true.connect(on_fight_mode_true)
	wave_count_resource.updated.connect(on_wave_count_changed)
	enemy_count_resource.updated.connect(on_enemy_count_changed)
	
	# TODO: create propper wave starting with some kind of event
	get_tree().process_frame.connect(fight_mode_resource.set_value.bind(true), CONNECT_ONE_SHOT)
	tree_exiting.connect(fight_mode_resource.set_value.bind(false))

func on_fight_mode_true()->void:
	wave_count_resource.set_value(3)

func on_wave_count_changed()->void:
	if wave_count_resource.value == 0:
		fight_mode_resource.set_value(false)
		return
	
	# TODO: have some rule of enemy count & strength spawning
	enemy_count_resource.set_value(10)

func on_enemy_count_changed()->void:
	if fight_mode_resource.value == false:
		return
	if wave_count_resource.value == 0:
		return
	if enemy_count_resource.value > 0:
		return
	
	wave_count_resource.set_value(wave_count_resource.value - 1)
