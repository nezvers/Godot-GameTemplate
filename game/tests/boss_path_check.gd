## Checks the boss path rooms built by game/tools/build_boss_path.gd: door links both
## ways, sections (waves, spawn points, triggers, requires chain, gates), boss waves,
## markers on walkable floor, tile looks, colliders and the balance.json entries.
## Then plays room_C10's two sections to check the gate opens only after Section1.
##   Godot --headless --path . res://game/tests/boss_path_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const SCENES:String = "res://game/scenes/"
const ROOMS:Array[String] = ["room_C00", "room_C10", "room_C11", "room_C20", "room_C21", "room_C30", "room_C31"]
const BOSSES:Dictionary = {
	"room_C11": "giant_zombie_instance_resource.tres",
	"room_C21": "broodmother_instance_resource.tres",
	"room_C31": "plague_mother_instance_resource.tres",
}
## Floor source per look: base 1, mossy 10, bloody 20.
const LOOKS:Dictionary = {
	"room_C10": [20], "room_C11": [20],
	"room_C20": [10], "room_C21": [10],
	"room_C30": [10, 20], "room_C31": [10, 20],
}
const TRIGGERS:Array[String] = ["ArenaEntry", "ArenaSection1Entry", "ArenaSection2Entry"]
const GATE:int = 1 # ArenaDoorBlock.WallMode.GATE
const WALL_ON:int = 1 # ArenaDoorBlock.WallState.ON

var failures:int = 0
var checks:int = 0

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	var _actions:ActionResource = load(TD + "resources/global_resources/action_resource.tres")
	_actions.reset_resource()
	var _balance:Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/balance/balance.json"))

	var _room_1:Node = _load_room("room_1")
	var _boss_door:Node = _room_1.get_node("Behind/Stairs4")
	check(_boss_door.visible && _boss_door.monitoring, "room_1 Stairs4 is open")
	check(_boss_door.scene_path == SCENES + "room_C00.tscn", "room_1 Stairs4 leads to room_C00")
	_check_door_link("room_1", _boss_door)
	for _wave:SpawnWaveList in _room_1.get_node("EnemyManager/Section1").waves:
		check(!_wave.is_boss, "room_1 has no boss wave left")
	_room_1.free()

	for _name:String in ROOMS:
		var _room:Node = _load_room(_name)
		_check_room(_name, _room, _balance.rooms.get(_name, {}))
		_room.free()

	await _play_sections()
	print("boss_path_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _load_room(name:String)->Node:
	return (load(SCENES + name + ".tscn") as PackedScene).instantiate()

func _check_door_link(name:String, door:Node)->void:
	check(ResourceLoader.exists(door.scene_path), "%s %s target %s exists" % [name, door.name, door.scene_path])
	if !ResourceLoader.exists(door.scene_path):
		return
	var _target:Node = (load(door.scene_path) as PackedScene).instantiate()
	var _match:Node = null
	for _other:Node in _target.get_node("Behind").get_children():
		if _other.get_script() == door.get_script() && _other.tag == door.connect_tag:
			_match = _other
	check(_match != null, "%s %s arrives at a door tagged '%s'" % [name, door.name, door.connect_tag])
	if _match != null:
		check(_match.connect_tag == door.tag && _match.scene_path.get_file() == name + ".tscn",
			"%s %s: the door it arrives at leads back" % [name, door.name])
	_target.free()

func _check_room(name:String, room:Node, entry:Dictionary)->void:
	var _floor:TileMapLayer = room.get_node("Background/FloorLayer")
	var _holes:TileMapLayer = room.get_node("Background/ObstacleLayer")
	var _walls:TileMapLayer = room.get_node("WallLayer_Ysorted")
	# Wall tiles on a region's +x/+y edge are drawn on walkable floor; their colliders
	# sit one cell further out, so walkability goes by the colliders.
	var _blocked:Dictionary = {}
	for _shape:Node2D in _walls.get_node("StaticBody2D").get_children():
		_blocked[_walls.local_to_map(_shape.position)] = true
	var _walkable:Callable = func (position:Vector2)->bool:
		var _cell:Vector2i = _floor.local_to_map(position)
		return _floor.get_cell_source_id(_cell) != -1 && !_blocked.has(_cell) && _holes.get_cell_source_id(_cell) == -1

	var _doors:Array[Node] = []
	for _node:Node in room.get_node("Behind").get_children():
		if _node is SceneEntry:
			_doors.append(_node)
			_check_door_link(name, _node)
			check(_walkable.call(_node.position), "%s %s on walkable floor" % [name, _node.name])
	check(!_doors.is_empty(), "%s has doors" % name)
	check(_walkable.call(room.get_node("PlayerSpawner").position), "%s PlayerSpawner on walkable floor" % name)
	for _door:Node in _doors:
		check(_door.position.distance_to(room.get_node("PlayerSpawner").position) > 24.0, "%s PlayerSpawner off %s" % [name, _door.name])

	var _sections:Array[ArenaSection] = []
	for _i:int in 3:
		_sections.append(room.get_node("EnemyManager/Section%d" % (_i + 1)))
	var _points:Array[SpawnPoint] = []
	for _node:Node in room.get_node("EnemySpawnPoints").get_children():
		if _node is SpawnPoint:
			_points.append(_node)
			check(_walkable.call(_node.position), "%s %s on walkable floor" % [name, _node.name])
	var _boss_waves:int = 0
	for _i:int in 3:
		var _section:ArenaSection = _sections[_i]
		if _section.waves.is_empty():
			continue
		var _label:String = "%s Section%d" % [name, _i + 1]
		var _has_normal:bool = false
		var _boss_section:bool = false
		for _wave:SpawnWaveList in _section.waves:
			_has_normal = _has_normal || !_wave.is_boss
			if _wave.is_boss:
				_boss_waves += 1
				_boss_section = true
				check(_wave.instance_list.size() == 1 && _wave.instance_list[0].resource_path.get_file() == BOSSES.get(name, ""),
					"%s boss wave spawns its boss" % _label)
		var _normal_points:int = 0
		var _boss_points:int = 0
		for _point:SpawnPoint in _points:
			if _point.section == _section:
				if _point.boss_position:
					_boss_points += 1
				else:
					_normal_points += 1
		check(!_has_normal || _normal_points > 0, "%s has spawn points" % _label)
		check(!_boss_section || _boss_points == 1, "%s has a boss spawn" % _label)
		var _trigger:Node = room.get_node(TRIGGERS[_i])
		var _shapes:int = 0
		for _shape:Node in _trigger.get_children():
			if _shape is CollisionPolygon2D:
				_shapes += 1
				check(_walkable.call(_shape.position), "%s trigger %s on walkable floor" % [_label, _shape.name])
		check(_shapes > 0, "%s trigger has a shape" % _label)
		if _i > 0:
			check(_section.requires == _sections[_i - 1], "%s requires Section%d" % [_label, _i])
		var _entry_waves:Array = entry.get("sections", {}).get("Section%d" % (_i + 1), {}).get("waves", [])
		check(_entry_waves.size() == _section.waves.size(), "%s balance.json waves match the scene" % _label)
		for _w:int in mini(_entry_waves.size(), _section.waves.size()):
			check(int(_entry_waves[_w].count) == _section.waves[_w].count && _entry_waves[_w].get("is_boss", false) == _section.waves[_w].is_boss,
				"%s wave %d matches balance.json" % [_label, _w + 1])
	check(_boss_waves == (1 if BOSSES.has(name) else 0), "%s boss wave count" % name)

	# Each BlockWall line closes its passage: its ends meet a wall collider or hole.
	var _block_cells:Dictionary = {}
	for _node:Node in _walls.get_children():
		if _node is BlockWall:
			_block_cells[_walls.local_to_map(_node.position)] = _node.section
	for _cell:Vector2i in _block_cells:
		for _dir:Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var _a:bool = _block_cells.get(_cell + _dir) == _block_cells[_cell]
			var _b:bool = _block_cells.get(_cell - _dir) == _block_cells[_cell]
			var _other:Vector2i = Vector2i(_dir.y, _dir.x)
			var _block:bool = _block_cells.get(_cell + _other) == _block_cells[_cell] || _block_cells.get(_cell - _other) == _block_cells[_cell]
			if (_a || _b) && !_block:
				for _end:Vector2i in [_cell + _dir, _cell - _dir]:
					check(_block_cells.has(_end) || !_walkable.call(_walls.map_to_local(_end)),
						"%s BlockWall line at %s leaves a gap at %s" % [name, _cell, _end])

	var _gates:int = 0
	for _node:Node in _walls.get_children():
		if _node is BlockWall:
			check(_node.section != null && !_node.section.waves.is_empty(), "%s %s bound to a section with waves" % [name, _node.name])
			if _node.mode == GATE:
				_gates += 1
				check(_node.section != _sections[_sections.size() - 1], "%s %s gate opens on an earlier section" % [name, _node.name])
	check(_gates > 0, "%s has gates" % name)

	check(_walls.get_node("StaticBody2D").get_child_count() > 0, "%s wall colliders generated" % name)
	if name in LOOKS:
		var _counts:Dictionary = {}
		var _cells:Array[Vector2i] = _floor.get_used_cells()
		for _cell:Vector2i in _cells:
			var _src:int = _floor.get_cell_source_id(_cell)
			_counts[_src] = _counts.get(_src, 0) + 1
		var _share:float = 0.5 if LOOKS[name].size() == 1 else 0.2
		for _src:int in LOOKS[name]:
			check(_counts.get(_src, 0) > _cells.size() * _share, "%s floor look %d covers enough (%d/%d)" % [name, _src, _counts.get(_src, 0), _cells.size()])
		var _themed_walls:int = 0
		for _cell:Vector2i in _walls.get_used_cells():
			if _walls.get_cell_source_id(_cell) in LOOKS[name]:
				_themed_walls += 1
		check(_themed_walls > 0, "%s walls take the floor look" % name)

## Section2 of room_C10 stays shut until Section1 clears; then the gate drops and it fights.
func _play_sections()->void:
	var _room:Node = _load_room("room_C10")
	add_child(_room)
	await _frames(10)
	var _s1:ArenaSection = _room.get_node("EnemyManager/Section1")
	var _s2:ArenaSection = _room.get_node("EnemyManager/Section2")
	var _gates:Array[BlockWall] = []
	var _barriers2:Array[BlockWall] = []
	for _node:Node in _room.get_node("WallLayer_Ysorted").get_children():
		if _node is BlockWall:
			if _node.mode == GATE && _node.section == _s1:
				_gates.append(_node)
			elif _node.mode != GATE && _node.section == _s2:
				_barriers2.append(_node)
	check(!_gates.is_empty() && !_barriers2.is_empty(), "room_C10 has Section1 gates and Section2 barriers")
	check(_gates.all(func (w:BlockWall)->bool: return w.arena_door_block.state == WALL_ON), "gates start raised")

	_s2.try_start()
	check(!_s2.fight_active, "Section2 can't start before Section1")
	_s1.try_start()
	check(_s1.fight_active, "Section1 starts")
	_finish(_s1)
	await _frames(5)
	check(_gates.all(func (w:BlockWall)->bool: return w.arena_door_block.state != WALL_ON), "gates drop once Section1 is cleared")
	var _state:RoomStateResource = load(TD + "resources/global_resources/room_state_resource.tres")
	check(!_state.is_cleared(&"room_C10"), "room not cleared with Section2 left")
	_s2.try_start()
	check(_s2.fight_active, "Section2 starts after Section1")
	await _frames(5)
	check(_barriers2.all(func (w:BlockWall)->bool: return w.arena_door_block.state == WALL_ON), "Section2 barriers rise for its fight")
	_finish(_s2)
	await _frames(5)
	check(_state.is_cleared(&"room_C10"), "room cleared after both sections")
	_room.queue_free()
	await _frames(2)

## What the last kill does: every wave is past, then the section clears.
func _finish(section:ArenaSection)->void:
	section.enemy_count = 0
	section.wave_index = section.waves.size()
	section.mark_cleared()

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
