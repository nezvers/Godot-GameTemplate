## Bridges the per-section arena state back to the legacy global resources that
## the rest of the game still reads (RoomController, InfoTracker, music,
## processing/visibility components, hole/dash abilities, etc.).
##
## - fight_mode_resource      : true while ANY section is fighting.
## - remaining_wave_count_resource : sum of waves left across all sections.
## - enemy_count_resource     : sum of enemies left across active sections.
class_name ArenaSectionAggregator
extends Node

@export var sections:Array[ArenaSection]

@export var fight_mode_resource:BoolResource
@export var remaining_wave_count_resource:IntResource
@export var enemy_count_resource:IntResource

func _ready()->void:
	assert(fight_mode_resource != null)
	for _section:ArenaSection in sections:
		if _section == null:
			continue
		_section.fight_started.connect(_recompute)
		_section.cleared.connect(_recompute)
		_section.updated.connect(_recompute)
	_recompute.call_deferred()

func _exit_tree()->void:
	fight_mode_resource.set_value(false)
	if remaining_wave_count_resource != null:
		remaining_wave_count_resource.set_value(0)
	if enemy_count_resource != null:
		enemy_count_resource.set_value(0)

func _recompute()->void:
	var _any_fighting:bool = false
	var _waves_left:int = 0
	var _enemies_left:int = 0
	for _section:ArenaSection in sections:
		if _section == null:
			continue
		if _section.fight_active:
			_any_fighting = true
			_enemies_left += _section.enemy_count
		_waves_left += _section.remaining_waves()

	fight_mode_resource.set_value(_any_fighting)
	if remaining_wave_count_resource != null:
		remaining_wave_count_resource.set_value(_waves_left)
	if enemy_count_resource != null:
		enemy_count_resource.set_value(_enemies_left)
