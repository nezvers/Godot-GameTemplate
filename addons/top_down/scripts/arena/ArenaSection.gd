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
## Fired when a wave begins (index into waves). Not fired for restored sections.
signal wave_started(index:int)
## Fired when a wave is defeated, after the section advanced (or cleared).
signal wave_cleared(index:int)

## Waves for this section, authored inline in the room. Empty == cleared on entry.
@export var waves:Array[SpawnWaveList]

## Spawn density:
##   < 1  : only a fraction of spawn points are active (round, min 1), each holding 1.
##   >= 1 : every spawn point active, each maintaining round(spawn_density) enemies
##          (capped per point by SpawnPoint.max_simultaneous).
@export_range(0.1, 6.0, 0.1) var spawn_density:float = 1.0

## Enemies don't spawn closer than this to another enemy; 0 = no check.
@export var free_distance:float = 116.0

## Optional prerequisite section. try_start() is ignored until it is cleared.
@export var requires:ArenaSection

## VFX shown before an enemy appears.
@export var spawn_mark_instance_resource:InstanceResource
## VFX shown the moment an enemy spawns.
@export var spawn_partickle_instance_resource:InstanceResource

const DIFFICULTY:DifficultyResource = preload("res://addons/top_down/resources/global_resources/difficulty_resource.tres")
## Horde meta-upgrades: spawn_rate_ratio, wave_count_ratio, spawner_count.
const META:MetaUpgradeResource = preload("res://game/resources/meta_upgrade_resource.tres")
## Several enemies from one spawn event sit on a ring this wide around the point.
const GROUP_RADIUS:float = 8.0
## Most spawn points that run a spawn timer at once.
const MAX_TIMED_POINTS:int = 6

var fight_active:bool
## The player whose step started the fight (null when started otherwise).
var started_by:Node2D
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
## While > 0 the spawn loop waits, e.g. until a boss announcement has played.
var spawn_holds:int = 0
## Seconds between a timed point's extra spawns; 0 = no timers. Set per wave.
var spawn_interval:float = 0.0
## Points that also spawn every spawn_interval, whether or not their slots are
## free: the difficulty's timed_spawners plus the meta's, at most
## MAX_TIMED_POINTS and the active points. Picked at random per wave.
var timed_points:Array[SpawnPoint]
## Enemies created by one spawn event at a point. Set per wave.
var per_spawn:int = 1

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
## `by`: the player who walked in (co-op pulls the rest of the party to it).
func try_start(by:Node2D = null)->void:
	# co-op guests fight the host's waves (NetEntities applies them)
	if Net.is_guest():
		return
	if is_cleared || fight_active:
		return
	if requires != null && !requires.is_cleared:
		return
	started_by = by if is_instance_valid(by) else null
	start_fight()

func start_fight()->void:
	# Nothing to fight: clear immediately.
	if waves.is_empty():
		mark_cleared()
		return
	fight_active = true
	wave_index = 0
	enemy_count = _wave_quota(waves[0])
	_select_active_points()
	set_process(true)
	fight_started.emit()
	updated.emit()
	wave_started.emit(0)

## Pick which points spawn this wave and the per-point maintained count, from
## spawn_density. Recomputed per wave since boss waves use a different point list.
func _select_active_points()->void:
	# New wave: any marks still in flight belong to the previous wave's quota.
	pending_spawns = 0
	var _wave:SpawnWaveList = current_wave()
	var _source:Array[SpawnPoint] = boss_points if (_wave != null && _wave.is_boss) else spawn_points
	for _p:SpawnPoint in _source:
		_p.active_count = 0
	spawn_interval = DIFFICULTY.spawn_interval() / maxf(1.0 + META.stat("spawn_rate_ratio"), 0.1)
	per_spawn = maxi(1, 1 + int(META.stat("spawner_count")))
	if spawn_density < 1.0:
		per_point_cap = 1
		var _n:int = clampi(roundi(spawn_density * _source.size()), 1, _source.size())
		active_points = _source.slice(0, _n)
	else:
		per_point_cap = roundi(spawn_density)
		active_points = _source.duplicate()
	_select_timed_points()

## The wave's burst comes from the slots; each timer first fires one interval later.
func _select_timed_points()->void:
	timed_points.clear()
	if spawn_interval <= 0.0:
		return
	var _wanted:int = DIFFICULTY.timed_spawners() + int(META.stat("timed_spawners"))
	var _shuffled:Array[SpawnPoint] = active_points.duplicate()
	_shuffled.shuffle()
	timed_points = _shuffled.slice(0, clampi(_wanted, 0, mini(MAX_TIMED_POINTS, _shuffled.size())))
	for _p:SpawnPoint in timed_points:
		_p.cooldown_left = spawn_interval

## Kills needed to clear a wave; difficulty and meta scale normal waves, not bosses.
func _wave_quota(wave:SpawnWaveList)->int:
	if wave.is_boss:
		return wave.count
	var _ratio:float = DIFFICULTY.wave_count_multiplier() * (1.0 + META.stat("wave_count_ratio")) * CoopScaling.wave_ratio()
	return maxi(1, ceili(wave.count * _ratio))

## Most of a wave alive at once, -1 when uncapped (no max_alive, or a 0 difficulty ratio).
func _alive_cap(wave:SpawnWaveList)->int:
	var _ratio:float = DIFFICULTY.max_alive_multiplier()
	if wave.max_alive <= 0 || _ratio <= 0.0:
		return -1
	return maxi(1, ceili(wave.max_alive * _ratio))

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

## Every active point keeps its slots filled, so it refills when its enemies die
## (the wave's opening burst is that first fill). Timed points also spawn every
## spawn_interval seconds on their own timer, whether or not their enemies are
## alive. Both keep the kill quota, max_alive cap and free_distance checks.
func _process(delta:float)->void:
	if spawn_holds > 0 || Net.is_guest():
		return
	var _wave:SpawnWaveList = current_wave()
	if _wave == null:
		return

	## Alive (incl. split children) PLUS marks still animating, so the async mark
	## chain can never over-spawn past the wave's kill quota. A mark in the tree
	## also sits in root.nodes; it only counts once, through pending_spawns.
	var _loose:int = maxi(0, ActiveEnemy.root.nodes.size() - pending_spawns)
	var _committed:int = _loose + ActiveEnemy.root.children.size() + pending_spawns
	var _cap:int = _alive_cap(_wave)

	for _point:SpawnPoint in timed_points:
		_point.cooldown_left -= delta
	for _point:SpawnPoint in active_points:
		## One more shouldn't exceed what's left to kill this wave.
		if _committed >= enemy_count:
			return
		if _cap >= 0 && _committed >= _cap:
			return
		var _slots:int = mini(per_point_cap, _point.max_simultaneous) * per_spawn
		var _timer_due:bool = timed_points.has(_point) && _point.cooldown_left <= 0.0
		if !_timer_due && _point.active_count >= _slots:
			continue
		if !_filter_free_position(_point.global_position):
			continue
		var _count:int = mini(per_spawn, enemy_count - _committed)
		if _cap >= 0:
			_count = mini(_count, _cap - _committed)
		if _timer_due:
			_point.cooldown_left = spawn_interval
		else:
			_count = mini(_count, _slots - _point.active_count)
		for _i:int in _count:
			_point.active_count += 1
			_committed += 1
			pending_spawns += 1
			_create_spawn_mark(_wave, _point, _group_offset(_i, _count))

## Where the i-th of `count` enemies from one spawn event lands, around the point.
func _group_offset(index:int, count:int)->Vector2:
	if count <= 1:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(TAU * index / count) * GROUP_RADIUS

func _create_spawn_mark(wave:SpawnWaveList, point:SpawnPoint, offset:Vector2 = Vector2.ZERO)->void:
	var _spawn_position:Vector2 = point.global_position + offset

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
		wave_cleared.emit(wave_index - 1)
		return
	enemy_count = _wave_quota(waves[wave_index])
	_select_active_points()
	updated.emit()
	wave_cleared.emit(wave_index - 1)
	wave_started.emit(wave_index)

## Co-op guest: mirror the host's state of this section.
func apply_net_state(active:bool, cleared_now:bool, index:int, count:int)->void:
	if is_cleared:
		return
	if cleared_now:
		var _last:int = wave_index
		mark_cleared()
		wave_cleared.emit(_last)
		return
	if active && !fight_active:
		start_fight()
	if active:
		while wave_index < index && wave_index < waves.size() - 1:
			wave_index += 1
			wave_cleared.emit(wave_index - 1)
			wave_started.emit(wave_index)
	enemy_count = count
	updated.emit()

func _filter_free_position(position:Vector2)->bool:
	if free_distance <= 0.0:
		return true
	# distance squared
	var _free_distance_squared:float = free_distance * free_distance

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
	return _closest_dist > _free_distance_squared
