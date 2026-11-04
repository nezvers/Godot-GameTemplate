## Spawn pacing per difficulty and the HORDE meta stats, in room_A02's first fight
## (4 spawn points). Every point refills its slots on both difficulties, so a full
## room stays full on Easy. Normal adds one timed point that also spawns every 2s
## whether or not its enemies are alive; each Nest upgrade adds a timed point with
## its own timer, up to 6 and the room's points. spawn_rate_ratio shortens the
## timer, wave_count_ratio grows normal waves and spawner_count makes every spawn
## event two enemies. Enemies are frozen and the
## kill quota raised, so only the pacing limits spawning. Nothing is saved.
##   Godot --headless --path . res://game/tests/spawn_timer_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const ROOM:String = "res://game/scenes/room_A02.tscn"
## The same resources ArenaSection preloads (vars: a const's properties can't be set).
var DIFFICULTY:DifficultyResource = load("res://addons/top_down/resources/global_resources/difficulty_resource.tres")
var META:MetaUpgradeResource = load("res://game/resources/meta_upgrade_resource.tres")
## Timing slack against physics frames.
const SLACK:float = 0.05

var failures:int = 0
var checks:int = 0

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	var _mode:int = DIFFICULTY.mode
	var _owned:PackedStringArray = META.owned.duplicate()

	check(is_equal_approx(_interval(DifficultyResource.Mode.NORMAL), 2.0), "Normal spawns every 2s")
	check(DIFFICULTY.timed_spawners() == 1, "Normal has one timed spawner")
	check(is_zero_approx(_interval(DifficultyResource.Mode.EASY)), "Easy waits for free slots")
	DIFFICULTY.mode = DifficultyResource.Mode.NORMAL
	check(DIFFICULTY.max_alive_multiplier() <= 0.0, "Normal has no max_alive cap")

	await _check_easy([], 1)
	await _check_easy(["twin_spawn"], 2)
	await _check_normal([], 2.0, 1, 1)
	await _check_normal(["swarm"], 1.0, 1, 1)
	await _check_normal(["twin_spawn"], 2.0, 2, 1)
	await _check_normal(["nest_1", "nest_2"], 2.0, 1, 3)
	# Six wanted, clamped to the room's 4 points.
	await _check_normal(["nest_1", "nest_2", "nest_3", "nest_4", "nest_5"], 2.0, 1, 4)
	await _check_independent()
	await _check_small_wave()
	await _check_quota()

	DIFFICULTY.mode = _mode
	META.owned = _owned
	print("spawn_timer_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _interval(mode:int)->float:
	DIFFICULTY.mode = mode
	return DIFFICULTY.spawn_interval()

## Slot mode: the burst fills each point's slots (times spawner_count), then nothing
## more spawns while every enemy stays alive.
func _check_easy(owned:Array, per_spawn:int)->void:
	DIFFICULTY.mode = DifficultyResource.Mode.EASY
	META.owned = PackedStringArray(owned)
	var _room:Node = await _start_room()
	var _section:ArenaSection = _room.get_node("EnemyManager/Section1")
	var _tag:String = "Easy %s" % [owned]
	var _times:Array[float] = await _watch(_section, 5.0)
	check(is_zero_approx(_section.spawn_interval) && _section.timed_points.is_empty(), "%s: no spawn timers" % _tag)
	var _burst:int = _section.active_points.size() * _section.per_point_cap * per_spawn
	check(_times.size() == _burst, "%s: burst of %d, then full slots hold (%d spawned)" % [_tag, _burst, _times.size()])
	if per_spawn > 1:
		_check_apart(_tag)
	await _end_room(_room)

## Slots give the opening burst, then each of `timed` points spawns again every
## `interval` seconds although every enemy is still alive.
func _check_normal(owned:Array, interval:float, per_spawn:int, timed:int)->void:
	DIFFICULTY.mode = DifficultyResource.Mode.NORMAL
	META.owned = PackedStringArray(owned)
	var _room:Node = await _start_room()
	var _section:ArenaSection = _room.get_node("EnemyManager/Section1")
	var _tag:String = "Normal %s" % [owned]
	var _span:float = interval * 2.0 + interval * 0.5
	var _times:Array[float] = await _watch(_section, _span)
	check(is_equal_approx(_section.spawn_interval, interval), "%s: %ss timer (%s)" % [_tag, interval, _section.spawn_interval])
	check(_section.timed_points.size() == timed, "%s: %d timed points (%d)" % [_tag, timed, _section.timed_points.size()])
	var _burst:int = _section.active_points.size() * _section.per_point_cap * per_spawn
	var _round:int = timed * per_spawn
	check(_times.size() == _burst + _round * 2, "%s: burst of %d, then two timer rounds of %d in %.1fs (%d spawned)" % [_tag, _burst, _round, _span, _times.size()])
	if _times.size() >= _burst + _round:
		check(_times[_burst - 1] <= SLACK, "%s: the opening is a burst (%.2fs)" % [_tag, _times[_burst - 1]])
		check(absf(_times[_burst] - interval) <= SLACK && absf(_times[_burst + _round - 1] - interval) <= SLACK, "%s: timers fire %.2fs later" % [_tag, _times[_burst]])
	check(ActiveEnemy.root.children.size() > _burst, "%s: spawns without waiting for kills" % _tag)
	await _end_room(_room)

## Each timed point has its own timer: holding one back delays only that point.
func _check_independent()->void:
	DIFFICULTY.mode = DifficultyResource.Mode.NORMAL
	META.owned = PackedStringArray(["nest_1", "nest_2", "nest_3"])
	var _room:Node = await _start_room()
	var _section:ArenaSection = _room.get_node("EnemyManager/Section1")
	var _delayed:Array[bool] = [false]
	var _delay:Callable = func (since_start:float)->void:
		if !_delayed[0] && since_start >= 0.5:
			_delayed[0] = true
			_section.timed_points[0].cooldown_left += 0.5
	var _times:Array[float] = await _watch(_section, 2.8, _delay)
	var _burst:int = _section.active_points.size() * _section.per_point_cap
	var _at_2:int = _times.filter(func (t:float)->bool: return absf(t - 2.0) <= SLACK).size()
	var _at_2_5:int = _times.filter(func (t:float)->bool: return absf(t - 2.5) <= SLACK).size()
	check(_times.size() == _burst + 4, "independent timers: burst + 4 (%d)" % _times.size())
	check(_at_2 == 3 && _at_2_5 == 1, "independent timers: 3 fire at 2s, the held one at 2.5s (%d, %d)" % [_at_2, _at_2_5])
	await _end_room(_room)

## Marks in flight count once against the kill quota. Swarm (1s timers, waves x2)
## and 4 timed points on a 4-kill wave (8 with Swarm): the timers fire at 1s while
## the burst's 4 marks still play, and all 8 fit (counted twice, none would).
func _check_small_wave()->void:
	DIFFICULTY.mode = DifficultyResource.Mode.NORMAL
	META.owned = PackedStringArray(["swarm", "nest_1", "nest_2", "nest_3"])
	var _room:Node = await _start_room(4)
	var _section:ArenaSection = _room.get_node("EnemyManager/Section1")
	var _times:Array[float] = await _watch(_section, 1.5)
	var _by_1s:int = _times.filter(func (t:float)->bool: return t <= 1.0 + SLACK).size()
	check(_times.size() == 8 && _by_1s == 8, "an 8-kill wave fills while marks are in flight (%d by 1s, %d)" % [_by_1s, _times.size()])
	await _end_room(_room)

## wave_count_ratio doubles normal waves only.
func _check_quota()->void:
	DIFFICULTY.mode = DifficultyResource.Mode.NORMAL
	var _wave:SpawnWaveList = SpawnWaveList.new()
	_wave.count = 10
	var _section:ArenaSection = ArenaSection.new()
	META.owned = PackedStringArray()
	var _base:int = _section._wave_quota(_wave)
	META.owned = PackedStringArray(["swarm"])
	check(_section._wave_quota(_wave) == _base * 2, "Swarm doubles a wave (%d -> %d)" % [_base, _section._wave_quota(_wave)])
	_wave.is_boss = true
	check(_section._wave_quota(_wave) == 10, "boss waves stay as they are")
	_section.free()

## Enemies of one spawn event don't land on the same spot.
func _check_apart(tag:String)->void:
	var _enemies:Array[Node2D] = ActiveEnemy.active_instances
	var _closest:float = INF
	for _i:int in _enemies.size():
		for _j:int in range(_i + 1, _enemies.size()):
			_closest = minf(_closest, _enemies[_i].global_position.distance_to(_enemies[_j].global_position))
	check(_enemies.size() > 1 && _closest > 4.0, "%s: paired spawns land apart (closest %.1f)" % [tag, _closest])

## Room whose first fight (started by the player standing in its trigger) has a
## kill quota too big to matter. Watching starts at once, so the burst is seen.
func _start_room(count:int = 1000)->Node:
	var _room:Node = (load(ROOM) as PackedScene).instantiate()
	add_child(_room)
	var _section:ArenaSection = _room.get_node("EnemyManager/Section1")
	# Frozen enemies stay on their point; let them stack so only the pacing limits spawns.
	_section.free_distance = 0.0
	_section.waves[0].count = count
	return _room

## Times (from the first spawn) of every spawn event over `seconds`, freezing
## enemies as they appear so none dies or wanders.
func _watch(section:ArenaSection, seconds:float, each_frame:Callable = Callable())->Array[float]:
	var _times:Array[float] = []
	var _last:int = 0
	var _elapsed:float = 0.0
	var _start:float = -1.0
	while _start < 0.0 || _elapsed - _start < seconds:
		await get_tree().physics_frame
		_elapsed += get_physics_process_delta_time()
		_freeze()
		section.try_start()
		# Spawned enemies plus marks in flight (a mark's own ActiveEnemy in root.nodes isn't counted).
		var _committed:int = ActiveEnemy.root.children.size() + section.pending_spawns
		if _committed > _last && _start < 0.0:
			_start = _elapsed
		for _i:int in maxi(0, _committed - _last):
			_times.append(_elapsed - _start)
		_last = maxi(_last, _committed)
		if _start >= 0.0 && each_frame.is_valid():
			each_frame.call(_elapsed - _start)
		if _elapsed > seconds + 20.0:
			break
	# Stop spawning and let the last marks turn into enemies, so none lands in the next room.
	section.set_process(false)
	var _left:int = 600
	while section.pending_spawns > 0 && _left > 0:
		await get_tree().physics_frame
		_left -= 1
	await _frames(2)
	_freeze()
	return _times

func _freeze()->void:
	for _enemy:Node2D in ActiveEnemy.active_instances:
		var _input:Node = _enemy.get_node_or_null("ZombieInput")
		if _input != null:
			_input.process_mode = Node.PROCESS_MODE_DISABLED

func _end_room(room:Node)->void:
	room.queue_free()
	await _frames(3)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
