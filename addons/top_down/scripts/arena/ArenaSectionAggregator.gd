## Bridges the per-section arena state back to the legacy global resources that
## the rest of the game still reads (RoomController, InfoTracker, music,
## processing/visibility components, hole/dash abilities, etc.).
##
## - fight_mode_resource      : true while ANY section is fighting.
## - remaining_wave_count_resource : sum of waves left across all sections.
## - enemy_count_resource     : sum of enemies left across active sections.
class_name ArenaSectionAggregator
extends Node

## A wave began in some section, with what a wave banner shows.
signal wave_announced(wave_number:int, enemies:int, is_boss:bool, boss_name:String)
## A wave was defeated. section_cleared: it was that section's last wave;
## sections_left counts this room's sections with waves still to fight.
signal wave_finished(wave_number:int, waves_left:int, section_cleared:bool, sections_left:int)

@export var sections:Array[ArenaSection]

@export var fight_mode_resource:BoolResource
@export var remaining_wave_count_resource:IntResource
@export var enemy_count_resource:IntResource

## 1-based wave number of the active section (0 when none fighting).
@export var wave_number_resource:IntResource

## Name of the section the player is currently in, e.g. "Section1".
@export var section_name_resource:StringValueResource

## Per-section cleared persistence + the current room id (set by RoomController).
@export var room_state_resource:RoomStateResource

## Cumulative wave numbers continue across sections, counting only sections the
## player has actually entered (or that were restored as already-cleared).
var _entered_offset:int = 0
## Per-section display base (wave number of its first wave minus 1), keyed by section.
var _base_for:Dictionary = {}

func _ready()->void:
	assert(fight_mode_resource != null)
	add_to_group(&"arena_aggregator")
	for _section:ArenaSection in sections:
		if _section == null:
			continue
		var _index:int = sections.find(_section)
		_section.fight_started.connect(_on_section_started.bind(_section))
		_section.cleared.connect(_on_section_cleared.bind(_index))
		_section.cleared.connect(_recompute)
		_section.updated.connect(_recompute)
		_section.wave_started.connect(_on_wave_started.bind(_section))
		_section.wave_cleared.connect(_on_wave_cleared.bind(_section))
	# Restore per-section state after every _ready (RoomController sets current_room_id).
	_restore_sections.call_deferred()
	_recompute.call_deferred()

## Re-mark sections cleared on room re-entry. Runs deferred so RoomController has
## already set the current room id and SectionStarter triggers are in-tree.
func _restore_sections()->void:
	if room_state_resource == null:
		return
	var _room_id:StringName = room_state_resource.current_room_id
	# No room id (room lacks a RoomController) -> don't touch shared persistence,
	# or every such room would collide on the empty key.
	if String(_room_id).is_empty():
		return
	for _i:int in sections.size():
		var _section:ArenaSection = sections[_i]
		if _section == null:
			continue
		if room_state_resource.is_section_cleared(_room_id, _i):
			# Treat a restored section as already-entered so later sections keep
			# the cumulative count, then clear it (frees its SectionStarter too).
			_entered_offset += _section.waves.size()
			_section.mark_cleared()

func _on_section_started(section:ArenaSection)->void:
	# This section's first wave continues from the running offset.
	_base_for[section] = _entered_offset
	_entered_offset += section.waves.size()
	if section_name_resource != null:
		section_name_resource.set_value("Section%d" % (sections.find(section) + 1))
	_recompute()

func _on_wave_started(index:int, section:ArenaSection)->void:
	var _wave:SpawnWaveList = section.waves[index]
	wave_announced.emit(_base_for.get(section, 0) + index + 1, _wave.count, _wave.is_boss, _wave.display_name)

func _on_wave_cleared(index:int, section:ArenaSection)->void:
	var _sections_left:int = 0
	for _section:ArenaSection in sections:
		if _section != null && !_section.is_cleared && !_section.waves.is_empty():
			_sections_left += 1
	wave_finished.emit(_base_for.get(section, 0) + index + 1, section.remaining_waves(), section.is_cleared, _sections_left)

func _on_section_cleared(index:int)->void:
	if room_state_resource == null:
		return
	if String(room_state_resource.current_room_id).is_empty():
		return
	room_state_resource.mark_section_cleared(room_state_resource.current_room_id, index)

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
	var _wave_number:int = 0
	for _section:ArenaSection in sections:
		if _section == null:
			continue
		if _section.fight_active:
			_any_fighting = true
			_enemies_left += _section.enemy_count
			# Active section drives the displayed wave number; its base offsets it
			# so numbering continues cumulatively across entered sections (1-based).
			var _base:int = _base_for.get(_section, 0)
			_wave_number = _base + _section.wave_index + 1
		_waves_left += _section.remaining_waves()

	fight_mode_resource.set_value(_any_fighting)
	if remaining_wave_count_resource != null:
		remaining_wave_count_resource.set_value(_waves_left)
	if enemy_count_resource != null:
		enemy_count_resource.set_value(_enemies_left)
	if wave_number_resource != null && _wave_number > 0:
		wave_number_resource.set_value(_wave_number)
