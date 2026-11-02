## Builds the boss path rooms (room_C00 hub and the three boss branches) from the
## ASCII maps below and writes them as scenes inheriting room_template.tscn.
## Re-run after editing a map; it overwrites the room scenes.
##   Godot --headless --path . res://game/tools/build_boss_path.tscn [-- C00 C10 ...]
##
## Map cells are TileMapLayer coords: a column is +x (screen bottom-right), a row is
## +y (screen bottom-left). Every map cell except space is floor. Walls are generated
## around the floor: outside on the -x/-y edges, ON the floor cell on the +x/+y edges,
## so keep doors, spawns and triggers off a region's last column and last row. Empty
## cells enclosed by floor become holes.
##   .  floor              D E F G  door (see "doors")
##   1 2 3  BARRIER BlockWall raised while that section fights
##   a b    GATE BlockWall up until Section1 / Section2 is cleared
##   x y z  trigger that starts Section1 / 2 / 3
##   p q r  spawn point of Section1 / 2 / 3     B  boss spawn ("boss_section")
##   W  web trap   A  acid puddle   S  slime puddle
##   P  player spawn when the room is started directly (off the doors: a door under
##      the player sends them straight through it)
extends Node

const TEMPLATE:String = "res://addons/top_down/scenes/levels/room_template.tscn"
const TD:String = "res://addons/top_down/"
const SCENES:String = "res://game/scenes/"

## Floor/hole tileset source per look; walls use 0 for base (the autotiler maps it).
const LOOK_SOURCE:Dictionary = {"base": 1, "mossy": 10, "bloody": 20}
const CRACKED:Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
const CRACKED_CHANCE:float = 0.1
const BLOCK_WALL_MARKER:Vector2i = Vector2i(3, 0)
const TRIGGER_NODES:Array[String] = ["ArenaEntry", "ArenaSection1Entry", "ArenaSection2Entry"]
const PROPS:Dictionary = {
	"W": "scenes/obstacles/web_trap.tscn",
	"A": "scenes/obstacles/acid_puddle.tscn",
	"S": "scenes/obstacles/slime_puddle.tscn",
}
const DIAMOND:PackedVector2Array = [Vector2(0, -8), Vector2(16, 0), Vector2(0, 8), Vector2(-16, 0)]

## look: base look of every floor cell. "blotch" mixes mossy and bloody patches.
## accent: look of noise patches sprinkled over the base look.
## patches: [x0, y0, x1, y1, look] rectangles drawn over the rest.
const ROOMS:Dictionary = {
	"C00": {
		"name": "Crossroads",
		"look": "base",
		"patches": [[0, 12, 9, 16, "bloody"], [20, 12, 29, 16, "mossy"], [12, 20, 16, 29, "blotch"]],
		"doors": {
			"D": ["c00_room1", "boss_path", "room_1"],
			"E": ["c00_c10", "c10_c00", "room_C10"],
			"F": ["c00_c20", "c20_c00", "room_C20"],
			"G": ["c00_c30", "c30_c00", "room_C30"],
		},
		"sections": [
			{"waves": [
				{"count": 6, "enemies": ["slime", "zombie"]},
				{"count": 8, "enemies": ["slime", "zombie", "zombie_crawler"]},
			]},
		],
		"map": [
			"             ...",
			"             .D.",
			"             ...",
			"             ...",
			"             111",
			"             P..",
			"             xxx",
			"             ...",
			"        ..............",
			"        .p..........p.",
			"        ..............",
			"        ...  ....  ...",
			"        ...  ....  ...",
			"......a................a......",
			".E....a.......p........a...F..",
			"......a................a......",
			"        ..............",
			"        ...  ....  ...",
			"        ...  ....  ...",
			"        ..............",
			"        .p..........p.",
			"        ..............",
			"             ...",
			"             aaa",
			"             ...",
			"             ...",
			"             ...",
			"             .G.",
			"             ...",
			"             ...",
		],
	},
	"C10": {
		"name": "Shambles",
		"look": "bloody",
		"accent": "base",
		"doors": {
			"D": ["c10_c00", "c00_c10", "room_C00"],
			"E": ["c10_c11", "c11_c10", "room_C11"],
		},
		"sections": [
			{"waves": [
				{"count": 8, "enemies": ["zombie", "zombie_crawler"]},
			]},
			{"spawn_density": 2, "max_simultaneous": 2, "waves": [
				{"count": 10, "enemies": ["zombie", "bloater"]},
				{"count": 12, "enemies": ["zombie", "zombie_crawler", "bloater"]},
			]},
		],
		"map": [
			"                        ................",
			"                        ................",
			"      ............      ..q..........q..",
			"      ............      ................",
			"      ..p......p..      ....22....22....",
			"      ............      ....22....22....",
			"...1.x............a.2.y..................b.....",
			".D.1Px.....  .....a.2.y........q.........b..E..",
			"...1.x.....  .....a.2.y..................b.....",
			"      ............a.2.y.................",
			"      ............      ....22....22....",
			"      ..p......p..      ....22....22....",
			"      ............      ................",
			"      ............      ..q..........q..",
			"                        ................",
			"                        ................",
		],
	},
	"C11": {
		"name": "Giant Zombie arena",
		"look": "bloody",
		"accent": "base",
		"doors": {
			"D": ["c11_c10", "c10_c11", "room_C10"],
		},
		"boss_section": 2,
		"sections": [
			{"waves": [
				{"count": 6, "enemies": ["zombie", "zombie_crawler"]},
			]},
			{"waves": [
				{"count": 1, "is_boss": true, "display_name": "GIANT ZOMBIE", "enemies": ["giant_zombie"]},
			]},
		],
		# The 2x2 BARRIER blocks in the arena are pillars that rise with the boss:
		# his Charge stuns him on walls (holes don't stop him).
		"map": [
			"                   ........................",
			"                   ........................",
			"                   ..  ....................",
			"                   ..  ....................",
			"                   .....22...........22....",
			"                   .....22...........22....",
			"      ........     ........................",
			"      ........     ........................",
			"      ..p..p..     ........................",
			"...1.x........a.2.y........................",
			".D.1Px........a.2.y............B...........",
			"...1.x........a.2.y........................",
			"      ........a.2.y........................",
			"      ..p..p..     ........................",
			"      ........     ........................",
			"      ........     ........................",
			"                   .....22...........22....",
			"                   .....22...........22  ..",
			"                   ....................  ..",
			"                   ........................",
			"                   ........................",
			"                   ........................",
		],
	},
	"C20": {
		"name": "Overgrowth",
		"look": "mossy",
		"accent": "base",
		"doors": {
			"D": ["c20_c00", "c00_c20", "room_C00"],
			"E": ["c20_c21", "c21_c20", "room_C21"],
		},
		"sections": [
			{"waves": [
				{"count": 8, "enemies": ["skitter_spider"]},
				{"count": 6, "enemies": ["skitter_spider", "web_spider"]},
			]},
			{"spawn_density": 2, "max_simultaneous": 2, "waves": [
				{"count": 12, "enemies": ["skitter_spider", "web_spider"]},
			]},
		],
		"map": [
			"        ...",
			"        .D.",
			"        ...",
			"        111",
			"        P..",
			"        xxx",
			"  ................",
			"  ................",
			"  ..p..........p..",
			"  ...  .....   ...",
			"  ...  .....   ...",
			"  ................",
			"  ........p.......",
			"  ................",
			"  ....   ....  ...",
			"  ....   ....  ...",
			"  ..p..........p..",
			"  ................",
			"        aaa",
			"        ...",
			"        222",
			"        ...",
			"        yyy",
			"....................",
			"....................",
			"..q..............q..",
			"....W...............",
			"...............W....",
			"..........q..........b.....",
			".....................b..E..",
			".....................b.....",
			".........W..........",
			"....................",
			"...W............W...",
			"..q.........W....q..",
			"....................",
			"....................",
		],
	},
	"C21": {
		"name": "Broodmother nest",
		"look": "mossy",
		"accent": "bloody",
		"doors": {
			"D": ["c21_c20", "c20_c21", "room_C20"],
		},
		"boss_section": 2,
		"sections": [
			{"spawn_density": 2, "max_simultaneous": 2, "waves": [
				{"count": 12, "enemies": ["skitter_spider"]},
			]},
			{"waves": [
				{"count": 1, "is_boss": true, "display_name": "BROODMOTHER", "enemies": ["broodmother"]},
			]},
		],
		"map": [
			"                       ..........................",
			"                       ..........................",
			"                       ..........................",
			"                       ...   ..............   ...",
			"      ............     ...   .......W......   ...",
			"      .p.......p..     ..........................",
			"      ............     ..........................",
			"      ...      ...     .......W..................",
			"      ...      ...     ..................W.......",
			"      ...      ...     ..........................",
			"...1.x...      ...a.2.y..........................",
			".D.1Px...      ...a.2.y............  ...B........",
			"...1.x...      ...a.2.y............  ............",
			"      ...      ...a.2.y..........................",
			"      ...      ...     ..........................",
			"      ...      ...     ..........................",
			"      ...      ...     .................W........",
			"      .p.......p..     .........W................",
			"      ............     ..........................",
			"      ............     ...   .......W......   ...",
			"                       ...   ..............   ...",
			"                       ..........................",
			"                       ..........................",
			"                       ..........................",
		],
	},
	"C30": {
		"name": "Sump",
		"look": "blotch",
		"doors": {
			"D": ["c30_c00", "c00_c30", "room_C00"],
			"E": ["c30_c31", "c31_c30", "room_C31"],
		},
		"sections": [
			{"waves": [
				{"count": 8, "enemies": ["slime", "acid_slime"]},
			]},
			{"waves": [
				{"count": 10, "enemies": ["acid_slime", "bloater"]},
				{"count": 8, "enemies": ["bloater", "slime"]},
			]},
			# Optional side vault behind its own gate.
			{"spawn_density": 2, "max_simultaneous": 2, "waves": [
				{"count": 12, "enemies": ["slime", "slime_small", "acid_slime"]},
			]},
		],
		"map": [
			"        ...",
			"        .D.",
			"        ...",
			"        111",
			"        P..            ................",
			"        xxx            ................",
			"  ................     ..q..........q..",
			"  ................     ................",
			"  ..p..........p..     ...........A....",
			"  ....A...........     ......   .......",
			"  ...........A....a.2.y......   ........b.....",
			"  ................a.2.y.................b..E..",
			"  ................a.2.y....A............b.....",
			"  ................a.2.y..........q.....",
			"  .......A........     ................",
			"  ...A............     ................",
			"  ..p..........p..     ................",
			"  ................     ..q..........q..",
			"                       ................",
			"                       ................",
			"                             bbb",
			"                             ...",
			"                             333",
			"                             ...",
			"                             zzz",
			"                         ...........",
			"                         .r......r..",
			"                         ..S........",
			"                         .......S...",
			"                         ...........",
			"                         ...........",
			"                         ...S....S..",
			"                         .r......r..",
			"                         ...........",
		],
	},
	"C31": {
		"name": "Plague Mother pit",
		"look": "blotch",
		"doors": {
			"D": ["c31_c30", "c30_c31", "room_C30"],
		},
		"boss_section": 2,
		"sections": [
			{"waves": [
				{"count": 8, "enemies": ["acid_slime", "slime"]},
			]},
			{"waves": [
				{"count": 1, "is_boss": true, "display_name": "PLAGUE MOTHER", "enemies": ["plague_mother"]},
			]},
		],
		"map": [
			"                    ........................",
			"                    ........................",
			"                    ........................",
			"                    ........................",
			"                    ........................",
			"      .........     ........................",
			"      .........     .......  .....  ........",
			"      ..p...p..     .......  .....  ........",
			"      .........     ........................",
			"...1.x.........a.2.y........................",
			".D.1Px....A....a.2.y...........B............",
			"...1.x.........a.2.y........................",
			"      .........a.2.y........................",
			"      .........     ........................",
			"      ..p...p..     .......  .....  ........",
			"      .........     .......  .....  ........",
			"      .........     ........................",
			"                    ........................",
			"                    ........................",
			"                    ........................",
			"                    ........................",
			"                    ........................",
		],
	},
}


var _balance:Dictionary
var _problems:int = 0

func _ready()->void:
	_balance = JSON.parse_string(FileAccess.get_file_as_string("res://game/balance/balance.json"))
	var _only:PackedStringArray = OS.get_cmdline_user_args()
	for _key:String in ROOMS:
		if !_only.is_empty() && !_only.has(_key):
			continue
		build_room(_key, ROOMS[_key])
	print("build_boss_path: done, %d problems" % _problems)
	get_tree().quit(1 if _problems > 0 else 0)

## Generates tiles, colliders and BlockWalls on a template instance with the editor's
## own generators, then writes the room as a scene inheriting the template. (A packed
## instance can't be saved as inherited from a script, so the overrides are written out.)
func build_room(key:String, spec:Dictionary)->void:
	var _root:Node2D = (load(TEMPLATE) as PackedScene).instantiate()
	var _floor:TileMapLayer = _root.get_node("Background/FloorLayer")
	var _holes:TileMapLayer = _root.get_node("Background/ObstacleLayer")
	var _walls:TileMapLayer = _root.get_node("WallLayer_Ysorted")
	var _markers:TileMapLayer = _walls.get_node("BlockWallMarkerLayer")
	for _layer:TileMapLayer in [_floor, _holes, _walls, _markers]:
		_layer.clear()

	var _cells:Dictionary = _parse(spec.map)
	var _rng:RandomNumberGenerator = RandomNumberGenerator.new()
	_rng.seed = hash(key)
	var _noise:FastNoiseLite = FastNoiseLite.new()
	_noise.seed = hash(key)
	_noise.frequency = 0.12

	# Floor, then the editor's Generate-from-floor + Fix Visual passes on each layer.
	for _cell:Vector2i in _cells:
		var _atlas:Vector2i = Vector2i(0, 3)
		if _cells[_cell] == "." && _rng.randf() < CRACKED_CHANCE:
			_atlas = CRACKED[_rng.randi() % CRACKED.size()]
		_floor.set_cell(_cell, LOOK_SOURCE[_look_at(spec, _cell, _noise)], _atlas)
	for _layer:TileMapLayer in [_holes, _walls]:
		var _autotiler:Node = _child_with_script(_layer, "TileVisualAutotiler.gd")
		_autotiler.generate_from_floor()
		_autotiler.autotile()
	_child_with_script(_floor, "TileVisualAutotiler.gd").autotile()
	for _cell:Vector2i in _cells:
		if _cells[_cell] in ["1", "2", "3", "a", "b"]:
			_markers.set_cell(_cell, 1, BLOCK_WALL_MARKER)
	_walls.get_node("BlockWallGenerator").setup_scenes()
	for _body:Node in [_holes.get_node("StaticBody2D"), _walls.get_node("StaticBody2D")]:
		_body.setup_colliders()
	var _blocked:Dictionary = _collider_cells(_walls)
	_report(key, spec, _cells, _blocked, _holes)
	_check_spans(key, _cells, _blocked, _holes)

	var _out:SceneText = SceneText.new()
	var _path:String = SCENES + "room_" + key + ".tscn"
	_out.uid = _existing_uid(_path)
	_out.node("Room", "", {}, _out.ext("PackedScene", TEMPLATE))
	for _layer:TileMapLayer in [_floor, _holes, _walls]:
		_out.node(_layer.name, _root.get_path_to(_layer.get_parent()), {
			"tile_map_data": "PackedByteArray(\"%s\")" % Marshalls.raw_to_base64(_layer.tile_map_data),
		})
	for _body:Node in [_holes.get_node("StaticBody2D"), _walls.get_node("StaticBody2D")]:
		for _shape:CollisionPolygon2D in _body.get_children():
			_out.node(_shape.name, _root.get_path_to(_body), {
				"position": var_to_str(_shape.position),
				"polygon": var_to_str(_shape.polygon),
			}, "", "CollisionPolygon2D")

	var _sections:Array[String] = ["../../EnemyManager/Section1", "../../EnemyManager/Section2", "../../EnemyManager/Section3"]
	var _block_wall:String = _out.ext("PackedScene", TD + "scenes/obstacles/block_wall.tscn")
	for _node:Node in _walls.get_children():
		if !_node.has_meta("source_cell"):
			continue
		var _cell:Vector2i = _node.get_meta("source_cell")
		var _c:String = _cells[_cell]
		var _props:Dictionary = {"position": var_to_str(_node.position)}
		if _c in ["a", "b"]:
			_props.section = "NodePath(\"%s\")" % _sections[0 if _c == "a" else 1]
			_props.mode = "1" # ArenaDoorBlock.WallMode.GATE
		else:
			_props.section = "NodePath(\"%s\")" % _sections[int(_c) - 1]
		_props["metadata/generated_by_scene_tile"] = "true"
		_props["metadata/source_cell"] = var_to_str(_cell)
		_out.node(_node.name, "WallLayer_Ysorted", _props, _block_wall)

	var _door_scene:String = _out.ext("PackedScene", TD + "scenes/obstacles/door.tscn")
	var _spawn_script:String = _out.ext("Script", TD + "scripts/arena/SpawnPoint.gd")
	var _spawn_counts:Array[int] = [0, 0, 0]
	var _door_index:int = 0
	var _prop_counts:Dictionary = {}
	var _triggers:Array[String] = []
	var _spawns:Array[String] = []
	for _cell:Vector2i in _sorted(_cells.keys()):
		var _c:String = _cells[_cell]
		var _pos:String = var_to_str(_floor.map_to_local(_cell))
		if spec.doors.has(_c):
			_door_index += 1
			_out.node("Stairs" if _door_index == 1 else "Stairs%d" % _door_index, "Behind", {
				"position": _pos,
				"tag": "\"%s\"" % spec.doors[_c][0],
				"connect_tag": "\"%s\"" % spec.doors[_c][1],
				"scene_path": "\"%s%s.tscn\"" % [SCENES, spec.doors[_c][2]],
			}, _door_scene)
		elif _c == "P":
			_out.node("PlayerSpawner", ".", {"position": _pos})
		elif PROPS.has(_c):
			var _scene:PackedScene = load(TD + PROPS[_c])
			var _base:String = _scene.get_state().get_node_name(0)
			_prop_counts[_base] = _prop_counts.get(_base, 0) + 1
			_out.node("%s%d" % [_base, _prop_counts[_base]], "Behind", {"position": _pos}, _out.ext("PackedScene", TD + PROPS[_c]))
		elif _c in ["p", "q", "r", "B"]:
			var _index:int = spec.get("boss_section", 1) - 1 if _c == "B" else "pqr".find(_c)
			var _props:Dictionary = {"position": _pos, "script": _spawn_script, "section": "NodePath(\"%s\")" % _sections[_index]}
			var _name:String = "SpawnBoss"
			if _c == "B":
				_props.boss_position = "true"
			else:
				_spawn_counts[_index] += 1
				_name = "Spawn_S%d_%d" % [_index + 1, _spawn_counts[_index]]
				_props.max_simultaneous = str(_section_spec(spec, _index).get("max_simultaneous", 1))
			_spawns.append(_name)
			_out.node(_name, "EnemySpawnPoints", _props, "", "Marker2D")
		elif _c in ["x", "y", "z"]:
			_out.node("Trigger_X%d_Y%d" % [_cell.x, _cell.y], TRIGGER_NODES["xyz".find(_c)], {
				"position": _pos,
				"polygon": var_to_str(DIAMOND),
			}, "", "CollisionPolygon2D")

	_write_sections(_out, spec)
	_out.node("RoomController", ".", {
		"script": _out.ext("Script", "res://game/scripts/RoomController.gd"),
		"room_id": "&\"room_%s\"" % key,
		"room_state_resource": _out.ext("Resource", TD + "resources/global_resources/room_state_resource.tres"),
		"room_cleared_resource": _out.ext("Resource", "res://game/resources/room_cleared_resource.tres"),
		"fight_mode_resource": _out.ext("Resource", TD + "resources/arena_resources/fight_mode_resource.tres"),
		"remaining_wave_count_resource": _out.ext("Resource", TD + "resources/arena_resources/remaining_wave_count_resource.tres"),
		"arena_entry": "NodePath(\"../ArenaEntry\")",
	}, "", "Node")
	_out.node("GameHudOverlay", ".", {}, _out.ext("PackedScene", "res://game/scenes/game_hud_overlay.tscn"))
	_out.editable.append("EnemyManager")

	var _file:FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		_problem("%s: can't write %s" % [key, _path])
	else:
		_file.store_string(_out.text())
		_file.close()
	_root.free()

func _write_sections(out:SceneText, spec:Dictionary)->void:
	var _wave_script:String = out.ext("Script", TD + "scripts/arena/SpawnWaveList.gd")
	var _instance_script:String = out.ext("Script", "res://addons/great_games_library/resources/InstanceResource/InstanceResource.gd")
	for _i:int in spec.sections.size():
		var _spec:Dictionary = spec.sections[_i]
		var _waves:PackedStringArray = []
		for _wave_spec:Dictionary in _spec.waves:
			var _props:Dictionary = {"script": _wave_script}
			if _wave_spec.get("is_boss", false):
				_props.is_boss = "true"
				_props.display_name = "\"%s\"" % _wave_spec.display_name
			_props.count = str(_wave_spec.count)
			if _wave_spec.has("max_alive"):
				_props.max_alive = str(_wave_spec.max_alive)
			var _instances:PackedStringArray = []
			for _id:String in _wave_spec.enemies:
				_instances.append(out.ext("Resource", _instance_path(_id)))
			_props.instance_list = "Array[%s]([%s])" % [_instance_script, ", ".join(_instances)]
			_waves.append(out.sub("Resource", _props))
		var _props:Dictionary = {"waves": "Array[%s]([%s])" % [_wave_script, ", ".join(_waves)]}
		if _spec.has("spawn_density"):
			_props.spawn_density = "%.1f" % _spec.spawn_density
		if _i > 0:
			_props.requires = "NodePath(\"../Section%d\")" % _i
		out.node("Section%d" % (_i + 1), "EnemyManager", _props)

func _instance_path(id:String)->String:
	for _category:String in ["enemies", "bosses"]:
		if _balance[_category].has(id):
			return _balance[_category][id].instance
	_problem("unknown enemy id '%s'" % id)
	return ""

func _section_spec(spec:Dictionary, index:int)->Dictionary:
	return spec.sections[index] if index < spec.sections.size() else {}

## Keeps a rebuilt room's uid so references made by the editor stay valid.
func _existing_uid(path:String)->String:
	if FileAccess.file_exists(path):
		var _header:String = FileAccess.get_file_as_string(path).get_slice("\n", 0)
		var _at:int = _header.find("uid=\"")
		if _at != -1:
			return _header.substr(_at + 5).get_slice("\"", 0)
	return ResourceUID.id_to_text(ResourceUID.create_id())

## Look of a floor cell: patches win, then the room look with its accent noise.
func _look_at(spec:Dictionary, cell:Vector2i, noise:FastNoiseLite)->String:
	var _look:String = spec.look
	for _patch:Array in spec.get("patches", []):
		if cell.x >= _patch[0] && cell.y >= _patch[1] && cell.x <= _patch[2] && cell.y <= _patch[3]:
			_look = _patch[4]
	var _n:float = noise.get_noise_2d(cell.x, cell.y)
	if _look == "blotch":
		if _n > 0.12:
			return "mossy"
		if _n < -0.12:
			return "bloody"
		return "base"
	if spec.has("accent") && _n > 0.3:
		return spec.accent
	return _look

func _parse(map:Array)->Dictionary:
	var _cells:Dictionary = {}
	for _y:int in map.size():
		var _row:String = map[_y]
		for _x:int in _row.length():
			if _row[_x] != " ":
				_cells[Vector2i(_x, _y)] = _row[_x]
	return _cells

## Cells with a wall collider. The wall tiles on a region's +x/+y edge are drawn on
## floor cells but their colliders sit one cell further out, so those cells stay walkable.
func _collider_cells(walls:TileMapLayer)->Dictionary:
	var _blocked:Dictionary = {}
	for _shape:Node2D in walls.get_node("StaticBody2D").get_children():
		_blocked[walls.local_to_map(_shape.position)] = true
	return _blocked

## Prints the generated layout (# wall collider, o hole) and flags marked cells that
## ended up blocked.
func _report(key:String, spec:Dictionary, cells:Dictionary, blocked:Dictionary, holes:TileMapLayer)->void:
	var _size:Vector2i = Vector2i.ZERO
	for _cell:Vector2i in cells:
		_size = _size.max(_cell + Vector2i(2, 2))
	print("room_%s (%s)" % [key, spec.name])
	for _y:int in range(-1, _size.y):
		var _line:String = ""
		for _x:int in range(-1, _size.x):
			var _cell:Vector2i = Vector2i(_x, _y)
			var _c:String = cells.get(_cell, " ")
			var _covered:bool = blocked.has(_cell) || holes.get_cell_source_id(_cell) != -1
			if _covered && _c != " " && _c != ".":
				_problem("%s: '%s' at %s is under a wall collider or hole" % [key, _c, _cell])
			if blocked.has(_cell):
				_c = "#"
			elif holes.get_cell_source_id(_cell) != -1:
				_c = "o"
			_line += _c
		print("  " + _line)

## Every BlockWall and trigger line must reach a wall collider (or hole) at both ends,
## or the player walks around it.
func _check_spans(key:String, cells:Dictionary, blocked:Dictionary, holes:TileMapLayer)->void:
	var _walkable:Callable = func (cell:Vector2i)->bool:
		return cells.has(cell) && !blocked.has(cell) && holes.get_cell_source_id(cell) == -1
	for _cell:Vector2i in cells:
		var _c:String = cells[_cell]
		if !(_c in ["1", "2", "3", "a", "b", "x", "y", "z"]):
			continue
		# Blocks (pillars) stand free; only one-cell-thick lines close a passage.
		var _across:bool = cells.get(_cell + Vector2i(1, 0)) == _c || cells.get(_cell - Vector2i(1, 0)) == _c
		var _down:bool = cells.get(_cell + Vector2i(0, 1)) == _c || cells.get(_cell - Vector2i(0, 1)) == _c
		if _across && _down:
			continue
		# A line runs along the axis where it has a neighbour of the same char.
		for _dir:Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if cells.get(_cell + _dir) != _c && cells.get(_cell - _dir) != _c:
				continue
			for _step:Vector2i in [_dir, -_dir]:
				var _next:Vector2i = _cell + _step
				if cells.get(_next) != _c && _walkable.call(_next):
					_problem("%s: '%s' line at %s leaves a gap at %s" % [key, _c, _cell, _next])

func _problem(message:String)->void:
	_problems += 1
	printerr("PROBLEM: ", message)

func _child_with_script(node:Node, file:String)->Node:
	for _child:Node in node.get_children():
		if _child.get_script() != null && _child.get_script().resource_path.get_file() == file:
			return _child
	return null

## Row by row, so Stairs/spawn numbering follows the map reading order.
func _sorted(cells:Array)->Array:
	cells.sort_custom(func (a:Vector2i, b:Vector2i)->bool: return a.y < b.y || (a.y == b.y && a.x < b.x))
	return cells

## Minimal .tscn writer for an inherited scene: ext/sub resources, then node overrides.
class SceneText:
	var uid:String
	var editable:PackedStringArray = []
	var _ext_ids:Dictionary = {}
	var _ext_lines:PackedStringArray = []
	var _sub_lines:PackedStringArray = []
	var _node_lines:PackedStringArray = []

	## Returns ExtResource("id") for path, registering it once.
	func ext(type:String, path:String)->String:
		if !_ext_ids.has(path):
			var _id:String = "%d_%s" % [_ext_ids.size() + 1, path.get_file().get_basename().left(12)]
			_ext_ids[path] = _id
			var _uid:int = ResourceLoader.get_resource_uid(path)
			var _uid_text:String = " uid=\"%s\"" % ResourceUID.id_to_text(_uid) if _uid != ResourceUID.INVALID_ID else ""
			_ext_lines.append("[ext_resource type=\"%s\"%s path=\"%s\" id=\"%s\"]" % [type, _uid_text, path, _id])
		return "ExtResource(\"%s\")" % _ext_ids[path]

	## Adds a sub resource and returns SubResource("id").
	func sub(type:String, props:Dictionary)->String:
		var _id:String = "%s_%d" % [type, _sub_lines.size() + 1]
		_sub_lines.append("[sub_resource type=\"%s\" id=\"%s\"]\n%s" % [type, _id, _props_text(props)])
		return "SubResource(\"%s\")" % _id

	## parent "" is the root; a node with type or instance is new, else an override.
	func node(name:String, parent:String, props:Dictionary, instance:String = "", type:String = "")->void:
		var _head:String = "[node name=\"%s\"" % name
		if !type.is_empty():
			_head += " type=\"%s\"" % type
		if !parent.is_empty():
			_head += " parent=\"%s\"" % parent
		var _paths:PackedStringArray = []
		for _key:String in props:
			if String(props[_key]).begins_with("NodePath("):
				_paths.append("\"%s\"" % _key)
		if !_paths.is_empty():
			_head += " node_paths=PackedStringArray(%s)" % ", ".join(_paths)
		if !instance.is_empty():
			_head += " instance=%s" % instance
		_node_lines.append(_head + "]\n" + _props_text(props))

	func _props_text(props:Dictionary)->String:
		var _text:String = ""
		for _key:String in props:
			_text += "%s = %s\n" % [_key, props[_key]]
		return _text

	func text()->String:
		var _parts:PackedStringArray = ["[gd_scene format=4 uid=\"%s\"]\n" % uid, "\n".join(_ext_lines) + "\n"]
		for _line:String in _sub_lines:
			_parts.append(_line)
		for _line:String in _node_lines:
			_parts.append(_line)
		for _path:String in editable:
			_parts.append("[editable path=\"%s\"]\n" % _path)
		return "\n".join(_parts)
