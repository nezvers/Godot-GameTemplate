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

## Spawn density:
##   < 1  : only a fraction of spawn points are active (round, min 1), each holding 1.
##   >= 1 : every spawn point active, each maintaining round(spawn_density) enemies
##          (capped per point by SpawnPoint.max_simultaneous).
@export_range(0.1, 6.0, 0.1) var spawn_density:float = 1.0

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
var spawn_points:Array[SpawnPoint]
var boss_points:Array[SpawnPoint]

## Subset of points actually spawning this wave (density-selected).
var active_points:Array[SpawnPoint]
## Per-point maintained enemy count for this wave (before each point's cap).
var per_point_cap:int = 1
## Spawn marks in flight (mark playing, enemy not yet in tree). Counted against
## the wave quota so an async mark chain can't over-spawn past enemy_count.
var pending_spawns:int = 0

func _ready()->void:
	set_process(false)

func _exit_tree()->void:
	# ActiveEnemy uses static state shared across rooms; reset on room teardown.
	# Harmless if run by each of the room's sections.
	ActiveEnemy.root = ActiveEnemyResource.new()
	ActiveEnemy.active_instances.clear()
	ActiveEnemy.instance_dictionary.clear()

## Called by SpawnPoint markers in their _ready.
func register_point(point:SpawnPoint)->void:
	spawn_points.append(point)

func register_boss_point(point:SpawnPoint)->void:
	boss_points.append(point)

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
	_select_active_points()
	set_process(true)
	fight_started.emit()
	updated.emit()

## Pick which points spawn this wave and the per-point maintained count, from
## spawn_density. Recomputed per wave since boss waves use a different point list.
func _select_active_points()->void:
	# New wave: any marks still in flight belong to the previous wave's quota.
	pending_spawns = 0
	var _wave:SpawnWaveList = current_wave()
	var _source:Array[SpawnPoint] = boss_points if (_wave != null && _wave.is_boss) else spawn_points
	for _p:SpawnPoint in _source:
		_p.active_count = 0
	if spawn_density < 1.0:
		per_point_cap = 1
		var _n:int = clampi(roundi(spawn_density * _source.size()), 1, _source.size())
		active_points = _source.slice(0, _n)
	else:
		per_point_cap = roundi(spawn_density)
		active_points = _source.duplicate()

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

	## Alive (incl. split children) PLUS marks still animating, so the async mark
	## chain can never over-spawn past the wave's kill quota.
	var _committed:int = ActiveEnemy.root.nodes.size() + ActiveEnemy.root.children.size() + pending_spawns

	for _point:SpawnPoint in active_points:
		## One more shouldn't exceed what's left to kill this wave.
		if _committed >= enemy_count:
			return
		var _cap:int = mini(per_point_cap, _point.max_simultaneous)
		if _point.active_count >= _cap:
			continue
		if !_filter_free_position(_point.global_position):
			continue
		_point.active_count += 1
		_committed += 1
		pending_spawns += 1
		_create_spawn_mark(_wave, _point)

func _create_spawn_mark(wave:SpawnWaveList, point:SpawnPoint)->void:
	var _spawn_position:Vector2 = point.global_position

	## after despawning creates actual enemy
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _spawn_position
		inst.tree_exiting.connect(_create_enemies.bind(_spawn_position, point), CONNECT_ONE_SHOT)
	spawn_mark_instance_resource.instance(_config_callback)

func _create_enemies(spawn_position:Vector2, point:SpawnPoint)->void:
	# Mark finished animating: it is no longer "pending", it becomes a real enemy.
	pending_spawns = maxi(0, pending_spawns - 1)

	var _partickle_config:Callable = func(inst:Node2D)->void:
		inst.global_position = spawn_position
	spawn_partickle_instance_resource.instance(_partickle_config)

	var _wave:SpawnWaveList = current_wave()
	if _wave == null:
		point.active_count = maxi(0, point.active_count - 1)
		return

	var _enemy_config:Callable = func (inst:Node2D)->void:
		inst.global_position = spawn_position
		ActiveEnemy.insert_child(inst, ActiveEnemy.root, _erase_enemy.bind(point))
	_wave.instance_list.pick_random().instance(_enemy_config)

func _erase_enemy(enemy:ActiveEnemy, point:SpawnPoint)->void:
	point.active_count = maxi(0, point.active_count - 1)
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
	_select_active_points()
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
