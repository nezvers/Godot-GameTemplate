## Checks every room built by game/tools/build_rooms.gd (New Game N rooms, New Game+
## P rooms, the C boss path): door and portal links both ways, sections (waves, spawn
## points, triggers, requires chain, gates), boss waves, markers and interactables on
## walkable floor, tile looks, colliders and the balance.json entries. Per campaign:
## every room reachable from its start, dead ends, the boss count, hub portals paired
## with the boss rooms and every interactable placed somewhere.
## Then plays: room_C10's gate opening only after Section1, a boss room's portal and
## victory exit opening once it is cleared (and the hub's portal back with it), the
## victory screen unlocking New Game+ for the title, the loot box opening once per
## run, and a campaign start resetting the run.
##   Godot --headless --path . res://game/tests/campaign_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const SCENES:String = "res://game/scenes/"
const CAMPAIGNS:Dictionary = {
	"new_game": preload("res://game/tools/rooms_new_game.gd"),
	"new_game_plus": preload("res://game/tools/rooms_new_game_plus.gd"),
	"boss_path": preload("res://game/tools/rooms_boss_path.gd"),
}
const BOSS_COUNT:Dictionary = {"new_game": 2, "new_game_plus": 3, "boss_path": 3}
const LOOK_SOURCE:Dictionary = {"base": 1, "mossy": 10, "bloody": 20, "metal": 30, "sandstone": 40, "flesh": 50}
const INTERACTABLES_DIR:String = TD + "scenes/interactables/"
## Contraptions of the home base memory grid, never in a campaign room
const HOME_ONLY:Array[String] = ["data_lever.tscn", "gate_lever.tscn", "reset_button.tscn", "write_button.tscn", "comms_terminal.tscn"]
const VICTORY:String = SCENES + "victory.tscn"
const TRIGGERS:Array[String] = ["ArenaEntry", "ArenaSection1Entry", "ArenaSection2Entry"]
const GATE:int = 1 # ArenaDoorBlock.WallMode.GATE
const WALL_ON:int = 1 # ArenaDoorBlock.WallState.ON

var failures:int = 0
var checks:int = 0
var _balance:Dictionary
var _state:RoomStateResource

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	var _actions:ActionResource = load(TD + "resources/global_resources/action_resource.tres")
	_actions.reset_resource()
	_balance = JSON.parse_string(FileAccess.get_file_as_string("res://game/balance/balance.json"))
	_state = load(TD + "resources/global_resources/room_state_resource.tres")

	var _room_1:Node = _load_room("room_1")
	var _boss_door:Node = _room_1.get_node("Behind/Stairs4")
	check(_boss_door.visible && _boss_door.monitoring, "room_1 Stairs4 is open")
	check(_boss_door.scene_path == SCENES + "room_C00.tscn", "room_1 Stairs4 leads to room_C00")
	_check_door_link("room_1", _boss_door)
	for _wave:SpawnWaveList in _room_1.get_node("EnemyManager/Section1").waves:
		check(!_wave.is_boss, "room_1 has no boss wave left")
	_room_1.free()

	for _campaign:String in CAMPAIGNS:
		var _rooms:Dictionary = CAMPAIGNS[_campaign].ROOMS
		for _key:String in _rooms:
			var _name:String = "room_" + _key
			var _room:Node = _load_room(_name)
			_check_room(_name, _rooms[_key], _room, _balance.rooms.get(_name, {}))
			_room.free()
		if CAMPAIGNS[_campaign].CAMPAIGN:
			_check_campaign(_campaign, _rooms)

	await _play_sections()
	await _play_portals()
	await _play_victory_unlock()
	await _play_loot_box()
	await _play_campaign_start()
	print("campaign_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _load_room(name:String)->Node:
	return (load(SCENES + name + ".tscn") as PackedScene).instantiate()

func _entries(room:Node)->Array[SceneEntry]:
	var _list:Array[SceneEntry] = []
	for _node:Node in room.get_node("Behind").get_children():
		if _node is SceneEntry:
			_list.append(_node)
	return _list

func _check_door_link(name:String, door:Node)->void:
	if door.scene_path == VICTORY:
		check(ResourceLoader.exists(VICTORY), "%s %s: the victory screen exists" % [name, door.name])
		return
	check(ResourceLoader.exists(door.scene_path), "%s %s target %s exists" % [name, door.name, door.scene_path])
	if !ResourceLoader.exists(door.scene_path):
		return
	var _target:Node = (load(door.scene_path) as PackedScene).instantiate()
	var _match:Node = null
	for _other:Node in _target.get_node("Behind").get_children():
		if _other.get_script() == door.get_script() && _other.tag == door.connect_tag:
			_match = _other
	check(_match != null, "%s %s arrives at a %s tagged '%s'" % [name, door.name, "portal" if door is Portal else "door", door.connect_tag])
	if _match != null:
		check(_match.connect_tag == door.tag && _match.scene_path.get_file() == name + ".tscn",
			"%s %s: the door it arrives at leads back" % [name, door.name])
	_target.free()

func _check_room(name:String, spec:Dictionary, room:Node, entry:Dictionary)->void:
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

	var _doors:Array[SceneEntry] = _entries(room)
	for _door:SceneEntry in _doors:
		_check_door_link(name, _door)
		check(_walkable.call(_door.position), "%s %s on walkable floor" % [name, _door.name])
	check(!_doors.is_empty(), "%s has doors" % name)
	check(_walkable.call(room.get_node("PlayerSpawner").position), "%s PlayerSpawner on walkable floor" % name)
	for _door:SceneEntry in _doors:
		check(_door.position.distance_to(room.get_node("PlayerSpawner").position) > 24.0, "%s PlayerSpawner off %s" % [name, _door.name])
	for _node:Node in _walls.get_children():
		if _node is Interactable:
			check(_walkable.call(_node.position), "%s %s on walkable floor" % [name, _node.name])

	if spec.get("start", false):
		var _fresh:Node = room.get_node_or_null("FreshStart")
		check(_fresh != null && _fresh.campaign_resource != null, "%s is a campaign start (FreshStart)" % name)
		check(_fresh != null && _fresh.run_resources.has(_state), "%s start resets the room state" % name)
		var _weapon:StartingWeaponSpawner = room.get_node_or_null("StartingWeapon")
		check(_weapon != null && _weapon.position_nodes.size() == 1, "%s places one starting weapon" % name)
		if _weapon != null:
			for _spot:Node2D in _weapon.position_nodes:
				check(_walkable.call(_spot.position), "%s %s on walkable floor" % [name, _spot.name])
			check(_weapon.exit_nodes.size() == _doors.size(), "%s doors open once the weapon is picked up" % name)

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
				check(_wave.instance_list.size() == 1 && _wave.instance_list[0].resource_path == _boss_instance(spec),
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
		if _i + 1 == spec.get("side_room", 0):
			check(_section.requires == null, "%s side room can be fought any time" % _label)
		elif _i > 0:
			check(_section.requires == _sections[_i - 1], "%s requires Section%d" % [_label, _i])
		var _entry_waves:Array = entry.get("sections", {}).get("Section%d" % (_i + 1), {}).get("waves", [])
		check(_entry_waves.size() == _section.waves.size(), "%s balance.json waves match the scene" % _label)
		for _w:int in mini(_entry_waves.size(), _section.waves.size()):
			check(int(_entry_waves[_w].count) == _section.waves[_w].count && _entry_waves[_w].get("is_boss", false) == _section.waves[_w].is_boss,
				"%s wave %d matches balance.json" % [_label, _w + 1])
	check(_boss_waves == (1 if spec.has("boss_section") else 0), "%s boss wave count" % name)

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
	var _side:ArenaSection = _sections[spec.side_room - 1] if spec.has("side_room") else null
	for _node:Node in _walls.get_children():
		if _node is BlockWall:
			check(_node.section != null && !_node.section.waves.is_empty(), "%s %s bound to a section with waves" % [name, _node.name])
			if _node.mode == GATE:
				_gates += 1
				check(_node.section != _sections[_sections.size() - 1], "%s %s gate opens on an earlier section" % [name, _node.name])
				check(_node.section != _side, "%s %s: no way on waits for the side room" % [name, _node.name])
	var _exits:int = 0
	for _door:SceneEntry in _doors:
		if !(_door is Portal):
			_exits += 1
	check(_gates > 0 || _exits < 2 || spec.sections.is_empty(), "%s has gates" % name)

	check(_walls.get_node("StaticBody2D").get_child_count() > 0, "%s wall colliders generated" % name)
	_check_looks(name, spec, _floor, _walls)

	if spec.has("boss_section") && spec.has("portals"):
		var _hub:Portal = null
		var _victory:Portal = null
		for _door:SceneEntry in _doors:
			if _door is Portal:
				check(_door.open_when_cleared == StringName(name), "%s %s waits for the boss" % [name, _door.name])
				if _door.scene_path == VICTORY:
					_victory = _door
				else:
					_hub = _door
					check(!_door.destination_name.is_empty(), "%s %s names the room it leads to" % [name, _door.name])
		check(_hub != null, "%s has a portal to the hub" % name)
		check(_victory != null, "%s has a victory exit" % name)

## Floor share of the room look (the accent and patches cover the rest), and walls
## following the floor look.
func _check_looks(name:String, spec:Dictionary, floor:TileMapLayer, walls:TileMapLayer)->void:
	var _sources:Array = [10, 20] if spec.look == "blotch" else [LOOK_SOURCE[spec.look]]
	if spec.has("patches") || _sources == [1]:
		return
	var _counts:Dictionary = {}
	var _cells:Array[Vector2i] = floor.get_used_cells()
	for _cell:Vector2i in _cells:
		var _src:int = floor.get_cell_source_id(_cell)
		_counts[_src] = _counts.get(_src, 0) + 1
	var _share:float = 0.5 if _sources.size() == 1 else 0.2
	for _src:int in _sources:
		check(_counts.get(_src, 0) > _cells.size() * _share, "%s floor look %d covers enough (%d/%d)" % [name, _src, _counts.get(_src, 0), _cells.size()])
	var _themed_walls:int = 0
	for _cell:Vector2i in walls.get_used_cells():
		if walls.get_cell_source_id(_cell) in _sources:
			_themed_walls += 1
	check(_themed_walls > 0, "%s walls take the floor look" % name)

func _boss_instance(spec:Dictionary)->String:
	for _section:Dictionary in spec.sections:
		for _wave:Dictionary in _section.waves:
			if _wave.get("is_boss", false):
				return _balance.bosses[_wave.enemies[0]].instance
	return ""

## Reachable from the start through doors alone, dead ends, boss count, hub portals
## pairing with the boss rooms and every interactable placed somewhere.
func _check_campaign(campaign:String, rooms:Dictionary)->void:
	var _start:String = ""
	for _key:String in rooms:
		if rooms[_key].get("start", false):
			check(_start.is_empty(), "%s has one start room" % campaign)
			_start = _key
	check(!_start.is_empty(), "%s has a start room" % campaign)

	var _seen:Dictionary = {_start: true}
	var _queue:Array[String] = [_start]
	var _bosses:int = 0
	var _dead_ends:int = 0
	var _placed:Dictionary = {}
	while !_queue.is_empty():
		var _key:String = _queue.pop_front()
		var _room:Node = _load_room("room_" + _key)
		var _doors:int = 0
		for _door:SceneEntry in _entries(_room):
			if _door is Portal:
				continue
			_doors += 1
			var _next:String = _door.scene_path.get_file().get_basename().trim_prefix("room_")
			if rooms.has(_next) && !_seen.has(_next):
				_seen[_next] = true
				_queue.append(_next)
		for _node:Node in _room.get_node("WallLayer_Ysorted").get_children():
			if _node is Interactable:
				_placed[_node.scene_file_path] = true
		if rooms[_key].has("boss_section"):
			_bosses += 1
			_check_boss_portals(_key, _room)
		elif _doors == 1 && !rooms[_key].get("start", false):
			_dead_ends += 1
		_room.free()
	for _key:String in rooms:
		check(_seen.has(_key), "%s: room_%s reachable from room_%s" % [campaign, _key, _start])
	check(_bosses == BOSS_COUNT[campaign], "%s has %d bosses (%d)" % [campaign, BOSS_COUNT[campaign], _bosses])
	check(_dead_ends > 0, "%s has dead ends (%d)" % [campaign, _dead_ends])
	for _file:String in DirAccess.get_files_at(INTERACTABLES_DIR):
		if _file.ends_with(".tscn") && !HOME_ONLY.has(_file):
			check(_placed.has(INTERACTABLES_DIR + _file), "%s places %s in a room" % [campaign, _file])

## The hub portal the boss room's portal arrives at leads back and waits for the boss.
func _check_boss_portals(key:String, room:Node)->void:
	for _door:SceneEntry in _entries(room):
		if !(_door is Portal) || _door.scene_path == VICTORY:
			continue
		var _hub:Node = (load(_door.scene_path) as PackedScene).instantiate()
		var _match:Portal = null
		for _other:SceneEntry in _entries(_hub):
			if _other is Portal && _other.tag == _door.connect_tag:
				_match = _other
		check(_match != null && _match.open_when_cleared == StringName("room_" + key),
			"room_%s: the hub portal back waits for the boss room" % key)
		_hub.free()

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

## room_N12's portal and victory exit stay shut and hidden through the fight and open once the
## Giant Zombie's section clears; the Sun Court's portal to it opens with them, the one
## to the Broodmother stays shut.
func _play_portals()->void:
	_state.reset_resource()
	var _room:Node = _load_room("room_N12")
	add_child(_room)
	await _frames(10)
	var _portals:Array[SceneEntry] = _entries(_room).filter(func (e:SceneEntry)->bool: return e is Portal)
	check(_portals.size() == 2, "room_N12 has a portal and a victory exit")
	check(_portals.all(func (p:Portal)->bool: return !p.is_open && !p.monitoring && !p.visible), "boss room portals start shut and hidden")
	var _s1:ArenaSection = _room.get_node("EnemyManager/Section1")
	var _s2:ArenaSection = _room.get_node("EnemyManager/Section2")
	_s1.try_start()
	_finish(_s1)
	await _frames(5)
	check(_portals.all(func (p:Portal)->bool: return !p.is_open && !p.visible), "portals stay shut and hidden while the boss lives")
	_s2.try_start()
	check(_s2.fight_active, "the boss section starts")
	_finish(_s2)
	await _frames(5)
	check(_state.is_cleared(&"room_N12"), "room_N12 cleared once the boss dies")
	check(_portals.all(func (p:Portal)->bool: return p.is_open && p.monitoring && p.visible), "boss room portals open and show once the boss dies")
	for _portal:Portal in _portals:
		if _portal.scene_path == VICTORY:
			check(_portal.label.text == "EXTRACT", "the victory exit reads EXTRACT (%s)" % _portal.label.text)
			check(_portal.sprite.texture == Portal.EXTRACT_TEXTURE, "the victory exit is green")
		else:
			check(_portal.label.text == "SUN COURT", "the hub portal names the Sun Court (%s)" % _portal.label.text)
			check(_portal.sprite.texture != Portal.EXTRACT_TEXTURE, "the hub portal keeps the purple vortex")
	_room.queue_free()
	await _frames(2)

	var _hub:Node = _load_room("room_N02")
	add_child(_hub)
	await _frames(5)
	for _portal:SceneEntry in _entries(_hub):
		if _portal is Portal:
			var _open:bool = _portal.open_when_cleared == &"room_N12"
			check(_portal.is_open == _open && _portal.monitoring == _open && _portal.visible == _open,
				"room_N02 %s is %s" % [_portal.name, "open" if _open else "shut and hidden"])
			if _open:
				check(_portal.label.text == "COLOSSUS PIT", "room_N02 portal names the boss room (%s)" % _portal.label.text)
	_hub.queue_free()
	await _frames(2)

## Reaching the victory screen unlocks New Game+, and the title shows it only then.
## Uses a scratch save name so the player's own save is untouched.
func _play_victory_unlock()->void:
	var _campaign:CampaignResource = load("res://game/resources/campaign_resource.tres")
	var _name:String = _campaign.resource_name
	var _was:bool = _campaign.ng_plus_unlocked
	_campaign.resource_name = "CampaignCheck"
	_campaign.ng_plus_unlocked = false

	var _title:Node = (load(SCENES + "title.tscn") as PackedScene).instantiate()
	add_child(_title)
	await _frames(2)
	var _entry:Control = _title.get_node("MarginContainer/Control/Body/TitleMenu/NewGamePlus")
	check(!_entry.visible, "title hides New Game+ while locked")
	check(_title.get_node("NewGameComponent").scene_path == SCENES + "room_N00.tscn", "New Game starts room_N00")
	check(_title.get_node("NewGamePlusComponent").scene_path == SCENES + "room_P00.tscn", "New Game+ starts room_P00")

	var _victory:Node = (load(VICTORY) as PackedScene).instantiate()
	add_child(_victory)
	await _frames(2)
	check(_campaign.ng_plus_unlocked, "the victory screen unlocks New Game+")
	check(FileAccess.file_exists("user://CampaignCheck.tres"), "the unlock is saved")
	check(_entry.visible, "title shows New Game+ once unlocked")
	_victory.queue_free()
	_title.queue_free()
	await _frames(2)

	_campaign.delete_resource()
	_campaign.resource_name = _name
	_campaign.ng_plus_unlocked = _was

## A loot box pays out once; after leaving and coming back it stays empty.
func _play_loot_box()->void:
	_state.reset_resource()
	var _room:Node = _load_room("room_P21")
	add_child(_room)
	await _frames(5)
	var _box:LootBox = _room.get_node("WallLayer_Ysorted/LootBox1")
	var _drops:Array = []
	_box.paid_out.connect(func (drop:String, _amount:int, _weapon:ItemResource)->void: _drops.append(drop))
	check(!_box.is_opened(), "loot box starts closed")
	_box.try_use()
	await _frames(2)
	check(_box.is_opened() && _drops.size() == 1 && _drops[0] != "nothing", "loot box pays out when opened (%s)" % [_drops])
	_room.queue_free()
	await _frames(2)

	_room = _load_room("room_P21")
	add_child(_room)
	await _frames(5)
	_box = _room.get_node("WallLayer_Ysorted/LootBox1")
	var _again:Array = []
	_box.paid_out.connect(func (drop:String, _amount:int, _weapon:ItemResource)->void: _again.append(drop))
	check(_box.is_opened(), "loot box stays open after coming back")
	await _frames(20)
	_box.try_use()
	await _frames(2)
	check(_again.is_empty(), "an opened loot box pays nothing")
	_room.queue_free()
	await _frames(2)

## Starting room_N00 fresh clears the run's rooms and makes New Game the restart scene.
func _play_campaign_start()->void:
	var _campaign:CampaignResource = load("res://game/resources/campaign_resource.tres")
	_campaign.start_scene = CampaignResource.NEW_GAME_PLUS
	_state.mark_cleared(&"room_N12")
	var _transition:SceneTransitionResource = load(TD + "resources/global_resources/scene_transition_resource.tres")
	_transition.next_scene_path = ""
	var _room:Node = _load_room("room_N00")
	add_child(_room)
	await _frames(5)
	check(!_state.is_cleared(&"room_N12"), "a campaign start resets the cleared rooms")
	check(_campaign.restart_scene() == SCENES + "room_N00.tscn", "a campaign start becomes the restart scene")
	check(_pickups(_room).size() == 1, "a campaign start places one starting weapon pickup")
	check(!(_room.get_node("Behind/Stairs") as Node2D).visible, "the start room's door waits for the weapon")
	_room.queue_free()
	await _frames(2)

func _pickups(node:Node)->Array[Node]:
	var _list:Array[Node] = []
	var _script:Script = node.get_script()
	if _script != null && _script.get_global_name() == "ItemPickup" && node.is_inside_tree():
		_list.append(node)
	for _child:Node in node.get_children():
		_list.append_array(_pickups(_child))
	return _list

## What the last kill does: every wave is past, then the section clears.
func _finish(section:ArenaSection)->void:
	section.enemy_count = 0
	section.wave_index = section.waves.size()
	section.mark_cleared()

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
