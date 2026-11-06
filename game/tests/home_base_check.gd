## Home base (room_H00): the piston memory grid (lane selects, data lever, Write,
## water masking a bit, blocked cells), water gun shots, saving the room and the
## weapon flow between home and missions (one gun out, victory brings them home).
## Saves go to temp resource names, the user's own save files stay untouched.
## Scene changes are done by hand (Transition needs a real screen).
##   Godot --headless --path . res://game/tests/home_base_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const HOME:String = "res://game/scenes/room_H00.tscn"
const N00:String = "res://game/scenes/room_N00.tscn"
const VICTORY:String = "res://game/scenes/victory.tscn"

var failures:int = 0
var checks:int = 0

var _home:HomeBaseResource
var _campaign:CampaignResource
var _inventory:ItemCollectionResource
var _database:ItemCollectionResource
var _player_reference:ReferenceNodeResource
var _room:Node
var _saved_names:Dictionary = {}

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	_home = load("res://game/resources/home_base_resource.tres")
	_campaign = load("res://game/resources/campaign_resource.tres")
	_inventory = load(TD + "resources/ItemCollectionResource/weapon_inventory.tres")
	_database = load(TD + "resources/ItemCollectionResource/weapon_database.tres")
	_player_reference = load(TD + "resources/ReferenceNodeResources/player_reference.tres")
	for _resource:SaveableResource in [_home, _campaign]:
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name = _resource.resource_name + "_test"
		_resource.delete_resource()
	_home.reset_resource()

	var _gun:ItemResource = _item("Gun")
	var _shotgun:ItemResource = _item("Shotgun")
	_home.stash_inventory = PackedStringArray(["Gun"])
	# a weapon saved outside the room (older layout) comes back at the spot
	_home.dropped = [{"item": "Shotgun", "pos": Vector2(-5000, -5000)}]

	await _load_room(HOME)
	var _player:Node2D = _player_reference.node
	check(_player != null, "home: player spawned")
	if _player == null:
		_finish()
		return
	check(_inventory.list.size() == 1 && _inventory.list[0] == _gun, "home: stashed gun in hand")
	var _grid:PistonGrid = _room.get_node("WallLayer_Ysorted/PistonGrid")
	check(_grid.pistons.size() == 900, "home: 30x30 pistons")
	check(_grid.row_levers.size() == 30 && _grid.col_levers.size() == 30, "home: a lever per row and column")
	check(_pickup_names().has("Water Gun"), "home: water gun lies in the control room")
	check(!_item("Water Gun").unlocked, "water gun is never a random start weapon")
	for _pickup:ItemPickup in _home_base().pickups():
		if _pickup.item_resource == _shotgun:
			check(_pickup.global_position.distance_to(_room.get_node("WaterGunSpot").global_position) < 1.0, "home: weapon saved off the floor lies at the spot")
			_pickup.queue_free()

	_check_layout(_grid)
	await _check_gates(_grid)
	await _check_grid(_grid, _player)
	await _check_water_shot(_grid)

	_grid.set_gate(PistonGrid.Gate.NOR)
	# Drop the gun, leave and come back: grid, levers and the dropped gun are restored
	var _manager:WeaponManager = _player.get_node("WeaponManager")
	_manager.drop_weapon()
	await _frames(3)
	check(_inventory.list.is_empty(), "drop: inventory empty")
	var _dropped_at:Vector2 = Vector2.INF
	for _pickup:ItemPickup in _home_base().pickups():
		if _pickup.item_resource == _gun:
			_dropped_at = _pickup.global_position
	check(_dropped_at != Vector2.INF, "drop: gun lies at the player's feet")
	await _frames(6)
	check(_inventory.list.is_empty(), "drop: not picked up again right away")
	var _raised:PackedByteArray = _grid.piston_bytes()
	_room.queue_free()
	await _frames(3)
	check(FileAccess.file_exists(_home.get_save_file_path()), "home state saved")
	_home.load_resource(true)
	await _load_room(HOME)
	_grid = _room.get_node("WallLayer_Ysorted/PistonGrid")
	await _frames(2)
	check(_grid.piston_bytes() == _raised, "reload: piston states restored")
	check(_grid.is_selected(PistonGrid.Axis.ROW, 0) && _grid.row_levers[0].on, "reload: row lever restored")
	check(!_grid.data_value, "reload: data lever restored")
	var _restored:bool = false
	for _pickup:ItemPickup in _home_base().pickups():
		_restored = _restored || (_pickup.item_resource == _gun && _pickup.global_position.distance_to(_dropped_at) < 0.5)
	check(_restored, "reload: dropped gun back where it was")
	check(_pickup_names().count("Water Gun") == 1, "reload: one water gun, not a second one")
	check(_inventory.list.is_empty(), "reload: nothing in hand")

	# Two guns can't go out, one can
	var _exit:HomeExitGate = _room.get_node("Behind/HomeExit")
	_inventory.append(_gun)
	_inventory.append(_shotgun)
	check(!_exit.can_leave(), "exit: refuses two guns")
	_exit._on_body_entered(_player_reference.node)
	check(_exit.hint_label.visible, "exit: hint to drop the rest")
	_inventory.set_selected(1)
	_inventory.take()
	await _frames(2)
	check(_exit.can_leave(), "exit: one gun may go")
	_home_base().depart()
	check(_home.loadout == "Gun", "exit: the gun is the run's loadout (%s)" % _home.loadout)
	check(_home.stash_inventory.is_empty(), "exit: stash went out with the player")

	# Mission start with the carried gun: stairs open, random gun still offered
	await _load_room(N00)
	check(_inventory.list.size() == 1 && _inventory.list[0] == _gun, "N00: carried gun in hand")
	check(_home.loadout.is_empty(), "N00: loadout used up")
	var _stairs:SceneEntry = _room.get_node("Behind/Stairs")
	check(_stairs.visible && _stairs.collision_mask != 0, "N00: stairs open with a carried gun")
	check(_count_script(_room, "ItemPickup") == 1, "N00: random gun still placed")

	# With fists the stairs wait for the pickup
	await _load_room(N00)
	check(_inventory.list.is_empty(), "N00 fists: empty hands")
	_stairs = _room.get_node("Behind/Stairs")
	check(!_stairs.visible, "N00 fists: stairs hidden until the gun is picked up")

	# A won run brings its weapons home
	_inventory.append(_shotgun)
	await _load_room(VICTORY)
	check(_home.stash_inventory.has("Shotgun"), "victory: weapons stashed for home")
	await _load_room(HOME)
	check(_inventory.list.size() == 1 && _inventory.list[0] == _shotgun, "home after victory: shotgun in hand")
	_finish()

## Cell (0, 0) and lever 1 of each lane sit at the corner by the control room.
func _check_layout(grid:PistonGrid)->void:
	var _floor:TileMapLayer = grid.floor_layer
	var _corner:Vector2i = grid.origin_cell + Vector2i(1, 1)
	var _map:Callable = func (node:Node2D)->Vector2i: return _floor.local_to_map(_floor.to_local(node.global_position))
	check(_map.call(grid.row_levers[0]) == grid.origin_cell + Vector2i(1, 0), "layout: row lever 1 next to the corner")
	check(_map.call(grid.col_levers[0]) == grid.origin_cell + Vector2i(0, 1), "layout: column lever 1 next to the corner")
	check(_map.call(grid.row_levers[29]) == grid.origin_cell + Vector2i(1, -29), "layout: row lever 30 at the far end")
	check(grid.row_levers[0]._prompt_text().begins_with("Row 1:") && grid.row_levers[0].number_label.text == "1" && grid.col_levers[29].number_label.text == "30", "layout: levers numbered from 1 at the corner")
	var _control:Node2D = _room.get_node("WallLayer_Ysorted/WriteButton1")
	var _write_cell:Vector2i = _map.call(_control)
	check(_write_cell.x > _corner.x && _write_cell.y > _corner.y, "layout: control room past the lever corner")
	var _probe:Piston = grid.piston(Vector2i(4, 7))
	check(grid.cell_at(_probe.global_position) == Vector2i(4, 7), "layout: cell_at finds a piston's cell")
	# the visible tile spans 8px up and down from the footprint centre
	check(grid.cell_at(_probe.global_position + Vector2(0, -7)) == Vector2i(4, 7) && grid.cell_at(_probe.global_position + Vector2(0, 7)) == Vector2i(4, 7), "layout: cell_at covers the whole visible tile")
	check(grid.cell_at(_probe.global_position + Vector2(0, -9)) == Vector2i(5, 8), "layout: just above the tile is the cell behind")
	# y-sorts by its footprint: anything behind an upper edge has a smaller y
	var _shape:CollisionPolygon2D = _probe.body_shape
	var _centre:Vector2 = Vector2.ZERO
	for _point:Vector2 in _shape.polygon:
		_centre += _shape.global_transform * _point
	check((_centre / _shape.polygon.size()).distance_to(_probe.global_position) < 0.5, "layout: piston sorts at its footprint centre")
	# lowered it is floor: its sprite sorts above the whole plate, so whoever stands on it draws in front
	check(_probe.y_sort_enabled && !_probe.is_raised() && _probe.sprite.global_position.y < _probe.global_position.y - 8.0, "layout: lowered piston draws under anyone on it")
	check(is_equal_approx(_probe.sprite.global_position.y + _probe.sprite.offset.y, _probe.global_position.y + Piston.SPRITE_OFFSET_Y), "layout: lowered piston art stays on its tile")

## Lane selects combine through the gate lever.
func _check_gates(grid:PistonGrid)->void:
	var _gate_lever:GateLever = _room.get_node("WallLayer_Ysorted/GateLever1")
	var _reset:ResetButton = _room.get_node("WallLayer_Ysorted/ResetButton1")
	check(grid.gate == PistonGrid.Gate.AND && _gate_lever.value_label.text == "AND", "gate: starts at AND")
	check(!_reset._can_use(), "reset: denied with no lever on")
	grid.set_selected(PistonGrid.Axis.ROW, 0, true)
	grid.set_selected(PistonGrid.Axis.ROW, 1, true)
	grid.set_selected(PistonGrid.Axis.COL, 0, true)
	# 2 rows, 1 column on a 30x30 grid
	var _expected:Dictionary = {
		PistonGrid.Gate.AND: 2, PistonGrid.Gate.OR: 2 * 30 + 30 - 2, PistonGrid.Gate.XOR: 2 * 30 + 30 - 4,
		PistonGrid.Gate.NAND: 900 - 2, PistonGrid.Gate.NOR: 28 * 29, PistonGrid.Gate.XNOR: 900 - (2 * 30 + 30 - 4),
	}
	for _i:int in PistonGrid.Gate.size():
		check(grid.selected_count() == _expected[grid.gate], "gate %s: %d cells (%d)" % [PistonGrid.gate_name(grid.gate), _expected[grid.gate], grid.selected_count()])
		check(_gate_lever.value_label.text == PistonGrid.gate_name(grid.gate) && _gate_lever.sprite.frame == grid.gate, "gate %s: lever shows it" % PistonGrid.gate_name(grid.gate))
		_gate_lever._use()
	check(grid.gate == PistonGrid.Gate.AND, "gate: cycles back to AND")
	grid.set_gate(PistonGrid.Gate.XOR)
	check(grid.is_cell_selected(Vector2i(5, 0)) && !grid.is_cell_selected(Vector2i(0, 0)) && grid.is_cell_selected(Vector2i(0, 5)), "gate XOR: lanes without their crossing")
	check(grid.piston(Vector2i(5, 0)).select_overlay.visible && !grid.piston(Vector2i(0, 0)).select_overlay.visible, "gate XOR: preview follows the gate")
	grid.set_gate(PistonGrid.Gate.AND)
	check(_reset._can_use(), "reset: usable with levers on")
	_reset._use()
	check(!grid.row_select.has(1) && !grid.col_select.has(1) && !grid.row_levers[0].on, "reset: every lever off")
	check(grid.selected_count() == 0, "reset: nothing selected")
	await _frames(2)

func _check_grid(grid:PistonGrid, player:Node2D)->void:
	grid.ripple_delay = 0.0
	var _astar:AStarGrid2D = (load(TD + "resources/arena_resources/obstacle_astargrid_resource.tres") as AstarGridResource).value
	var _write_button:WriteButton = _room.get_node("WallLayer_Ysorted/WriteButton1")
	check(!_write_button._can_use(), "write: denied without a selection")
	grid.set_selected(PistonGrid.Axis.ROW, 0, true)
	grid.set_selected(PistonGrid.Axis.ROW, 2, true)
	grid.col_levers[1]._use()
	check(grid.is_selected(PistonGrid.Axis.COL, 1), "lever: using it selects its column")
	check(grid.selected_count() == 2, "select: rows {0,2} x column 1 = 2 cells")
	check(grid.piston(Vector2i(1, 0)).select_overlay.visible && !grid.piston(Vector2i(0, 0)).select_overlay.visible, "select: preview on the selected cells only")
	check(grid.col_levers[1].on && grid.col_levers[1].sprite.frame == 1, "select: lever shows on")
	grid.set_data_value(true)
	_write_button._use()
	await _frames(25)
	check(grid.piston(Vector2i(1, 0)).is_raised() && grid.piston(Vector2i(1, 2)).is_raised(), "write raise: selected cells up")
	check(!grid.piston(Vector2i(0, 0)).is_raised() && !grid.piston(Vector2i(1, 1)).is_raised(), "write raise: others stay down")
	var _tile:Vector2i = grid._map_cell(Vector2i(1, 2))
	check(_astar != null && _astar.is_point_solid(_tile), "write raise: raised cell solid for enemies")
	check(grid.piston(Vector2i(1, 2)).body_shape.disabled == false, "write raise: raised cell has collision")

	# Water masks one bit
	grid.piston(Vector2i(1, 2)).wet()
	var _results:Array[Dictionary] = [{}]
	grid.written.connect(func(results:Dictionary)->void: _results[0] = results, CONNECT_ONE_SHOT)
	grid.set_data_value(false)
	grid.write()
	await _frames(25)
	check(!grid.piston(Vector2i(1, 0)).is_raised(), "write lower: dry cell lowered")
	check(grid.piston(Vector2i(1, 2)).is_raised(), "write lower: wet cell shorted, stays up")
	check(_results[0].get(Piston.WriteResult.SHORTED, 0) == 1, "write lower: one short reported")
	check(grid.piston(Vector2i(1, 2)).spark_particles.emitting || grid.piston(Vector2i(1, 2)).spark_sprite.visible, "short: sparks play")
	var _wet:Piston = grid.piston(Vector2i(5, 5))
	_wet.wet_time = 0.1
	_wet.wet()
	check(_wet.is_wet() && _wet.wet_overlay.visible, "wet: overlay shown")
	await get_tree().create_timer(0.3).timeout
	check(!_wet.is_wet() && !_wet.wet_overlay.visible, "wet: dries after wet_time")

	# Nobody gets crushed: a raise under the player is refused
	var _under:Piston = grid.piston(Vector2i(3, 3))
	var _player_start:Vector2 = player.global_position
	player.global_position = _under.global_position
	await _frames(3)
	check(_under.try_write(true) == Piston.WriteResult.BLOCKED && !_under.is_raised(), "blocked: no raise under the player")
	player.global_position = _player_start
	await _frames(3)
	check(_under.try_write(true) == Piston.WriteResult.OK && _under.is_raised(), "blocked: raises once the player left")
	_under.set_raised(false)
	await _frames(25)
	# keep the row-0 selection and LOWER for the reload checks

func _check_water_shot(grid:PistonGrid)->void:
	var _shot:InstanceResource = load(TD + "resources/InstanceResources/projectiles/water_shot_projectile_instance_resource.tres")
	var _target:Piston = grid.piston(Vector2i(10, 10))
	var _neighbour:Piston = grid.piston(Vector2i(11, 10))
	# aimed at the upper part of the visible tile
	_fire(_shot, _target.global_position + Vector2(0, -5), _target.global_position + Vector2(-40, 0))
	await get_tree().create_timer(1.0).timeout
	check(_target.is_wet(), "water shot: target piston wet")
	check(!_neighbour.is_wet() && !grid.piston(Vector2i(11, 11)).is_wet(), "water shot: only that one piston")
	# a lowered piston hidden behind a raised one is hit by aiming at its cell
	var _front:Piston = grid.piston(Vector2i(12, 12))
	var _behind:Piston = grid.piston(Vector2i(13, 13))
	_front.set_raised(true, true)
	_fire(_shot, _behind.global_position, _behind.global_position + Vector2(-40, 0))
	await get_tree().create_timer(1.0).timeout
	check(_behind.is_wet() && !_front.is_wet(), "water shot: lowered piston behind a raised one")
	_front.set_raised(false, true)
	_behind.dry()
	var _spot:Vector2 = (_room.get_node("WaterGunSpot") as Node2D).global_position + Vector2(-24, 0)
	var _before:int = _count_script(_room, "PuddleTrap")
	_fire(_shot, _spot, _spot + Vector2(-30, 0))
	await get_tree().create_timer(1.0).timeout
	check(_count_script(_room, "PuddleTrap") == _before + 1, "water shot off the grid: water puddle")
	_target.dry()

func _fire(shot:InstanceResource, destination:Vector2, origin:Vector2)->void:
	shot.instance(func (inst:Projectile2D)->void:
		inst.global_position = origin
		inst.destination = destination
		inst.direction = (destination - origin).normalized()
	)

func _home_base()->HomeBase:
	return _room.get_node("HomeBase")

func _item(item_name:String)->ItemResource:
	return HomeBaseResource.find_item(_database, item_name)

func _pickup_names()->PackedStringArray:
	var _names:PackedStringArray = []
	for _pickup:ItemPickup in _home_base().pickups():
		_names.append(_pickup.item_resource.resource_name)
	return _names

func _load_room(path:String)->void:
	if _room != null:
		_room.queue_free()
		await _frames(3)
	_room = (load(path) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)

func _count_script(node:Node, script_name:String)->int:
	var _count:int = 0
	var _script:Script = node.get_script()
	if _script != null && _script.get_global_name() == script_name && node.is_inside_tree() && !node.is_queued_for_deletion():
		_count += 1
	for _child:Node in node.get_children():
		_count += _count_script(_child, script_name)
	return _count

func _finish()->void:
	if _room != null:
		_room.queue_free()
		await _frames(3)
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	print("home_base_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
