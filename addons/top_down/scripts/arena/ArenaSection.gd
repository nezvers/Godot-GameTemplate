## One independent arena fight, defined inline in the room scene.
##
## Replaces the old ArenaSectionResource (.tres) + spawner + wave-manager trio:
## a section now lives as a Node next to its trigger, holds its own waves,
## owns its spawn loop and wave progression, and carries no state between rooms.
##
## Wiring (all NodePath @exports to THIS node, set per room):
##   - SectionStarter (on the entry Area2D) calls try_start() on body_entered.
##   - SpawnPoint markers register their position via register_position().
##   - BlockWall/ArenaDoorBlock react to fight_started / cleared.
##   - DropManager listens to enemy_killed.
class_name ArenaSection
extends Node

## Fired once when the last wave is defeated.
signal cleared
## Fired when this section's fight begins.
signal fight_started
## General change notification (counts/mode) for HUD-style listeners.
signal updated
## Fired per enemy death (for DropManager).
signal enemy_killed(enemy:ActiveEnemy)

## Waves for this section, authored inline in the room. Empty == cleared on entry.
@export var waves:Array[SpawnWaveList]

## Optional prerequisite section. try_start() is ignored until it is cleared.
@export var requires:ArenaSection

## VFX shown before an enemy appears.
@export var spawn_mark_instance_resource:InstanceResource
## VFX shown the moment an enemy spawns.
@export var spawn_partickle_instance_resource:InstanceResource

var fight_active:bool
var is_cleared:bool
var wave_index:int
var enemy_count:int
var spawn_positions:Array[Vector2]
var boss_positions:Array[Vector2]

func _ready()->void:
	set_process(false)

func _exit_tree()->void:
	# ActiveEnemy uses static state shared across rooms; reset on room teardown.
	# Harmless if run by each of the room's sections.
	ActiveEnemy.root = ActiveEnemyResource.new()
	ActiveEnemy.active_instances.clear()
	ActiveEnemy.instance_dictionary.clear()

## Called by SpawnPoint markers in their _ready.
func register_position(position:Vector2)->void:
	spawn_positions.append(position)

func register_boss_position(position:Vector2)->void:
	boss_positions.append(position)

## Called by the section's entry trigger. Honors prerequisite and cleared state.
func try_start()->void:
	if is_cleared || fight_active:
		return
	if requires != null && !requires.is_cleared:
		return
	start_fight()

func start_fight()->void:
	# Nothing to fight: clear immediately.
	if waves.is_empty():
		mark_cleared()
		return
	fight_active = true
	wave_index = 0
	enemy_count = waves[0].count
	set_process(true)
	fight_started.emit()
	updated.emit()

## Current wave being fought, or null when none remain.
func current_wave()->SpawnWaveList:
	if wave_index >= waves.size():
		return null
	return waves[wave_index]

## Waves left to clear (current + not-yet-reached).
func remaining_waves()->int:
	return maxi(0, waves.size() - wave_index)

func mark_cleared()->void:
	if is_cleared:
		return
	fight_active = false
	is_cleared = true
	enemy_count = 0
	set_process(false)
	cleared.emit()
	updated.emit()

# --- Spawn loop (moved from EnemySpawner) ---------------------------------

func _process(_delta:float)->void:
	var _wave:SpawnWaveList = current_wave()
	if _wave == null:
		return

	# Boss fix: cap against the position list relevant to THIS wave, recomputed
	# per frame so a boss-only section (0 normal positions) still spawns.
	var _cap:int = boss_positions.size() if _wave.is_boss else spawn_positions.size()
	var _active_count:int = ActiveEnemy.root.nodes.size() + ActiveEnemy.root.children.size()

	if _cap - _active_count < 1:
		return
	## One more shouldn't exceed what's left to kill.
	if _active_count + 1 > enemy_count:
		return

	_create_spawn_mark(_wave)

func _create_spawn_mark(wave:SpawnWaveList)->void:
	var _source:Array[Vector2] = boss_positions if wave.is_boss else spawn_positions
	var _free_positions:Array[Vector2] = _source.filter(_filter_free_position)
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

	var _wave:SpawnWaveList = current_wave()
	if _wave == null:
		return

	var _enemy_config:Callable = func (inst:Node2D)->void:
		inst.global_position = spawn_position
		ActiveEnemy.insert_child(inst, ActiveEnemy.root, _erase_enemy)
	_wave.instance_list.pick_random().instance(_enemy_config)

func _erase_enemy(enemy:ActiveEnemy)->void:
	enemy_count -= 1
	updated.emit()
	enemy_killed.emit(enemy)
	_advance_wave()

## Advance once the current wave is emptied; clear when none remain.
func _advance_wave()->void:
	if !fight_active || enemy_count > 0:
		return
	wave_index += 1
	if wave_index >= waves.size():
		mark_cleared()
		return
	enemy_count = waves[wave_index].count
	updated.emit()

func _filter_free_position(position:Vector2)->bool:
	# distance squared
	const FREE_DISTANCE:float = 116.0 * 116.0

	var _closest_dist:float = 999999.0
	## Actual enemy instances
	var instance_list:Array[Node2D] = ActiveEnemy.active_instances
	for inst:Node2D in instance_list:
		assert(inst != null)
		# length_squared is faster (no sqrt) for closest-distance checks.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist

	# free distance was squared because it is compared against length_squared
	return _closest_dist > FREE_DISTANCE
