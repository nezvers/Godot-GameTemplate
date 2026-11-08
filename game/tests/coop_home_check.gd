## A guest in the host's home base, over ENet on 127.0.0.1 (net_client.tscn,
## mode "home"). This process hosts. Checks:
##   - the guest leaves its own stash at home and sees the host's base: the
##     host's weapons on the floor, shared (one picked up is gone for both);
##   - a guest is a ghost by default (faint in the home base, keeps nothing:
##     crystals taken back when it leaves) and an electrician with a printed shell;
##   - the guest's levers and Write button work the host's piston grid, the
##     outcome shows on both;
##   - leaving with one of the host's weapons puts it back on the host's floor.
## Save files get temp names on both sides.
##   Godot --headless --path . res://game/tests/coop_home_check.tscn
extends Node

const PORT:int = 24596
const HOME:String = "res://game/scenes/room_H00.tscn"
const DATABASE:String = "res://addons/top_down/resources/ItemCollectionResource/weapon_database.tres"

var failures:int = 0
var checks:int = 0
var _client:Dictionary
var _saved_names:Dictionary = {}

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	for _path:String in ["res://game/resources/home_base_resource.tres", "res://game/resources/campaign_resource.tres"]:
		var _resource:SaveableResource = load(_path)
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name += "_test"
		_resource.delete_resource()
		_resource.reset_resource()
	Transition.instant = true
	get_tree().current_scene = null
	_run.call_deferred()

func _run()->void:
	Transition.change_scene(HOME)
	check(await _wait(func ()->bool: return _body() != null, 10.0), "host: in the home base")
	await _frames(5)
	var _shotgun:ItemResource = HomeBaseResource.find_item(load(DATABASE), "Shotgun")
	Net.entities.drop_item(_shotgun, _body().global_position + Vector2(-40, 10))
	check(Net.host(PORT) == OK, "host: open to friends")
	await _frames(3)
	check(_floor_count("Shotgun") == 1, "host: a shotgun lies on the floor")
	check(_floor_count("Water Gun") == 1, "host: the water gun lies at its spot")
	_client = _spawn_client()

	# --- 1st visit: a ghost
	check(await _wait(func ()->bool: return _last("own_home") != "", 30.0), "guest: in its own home base first")
	check(_last("own_home") == "false held=Gun", "guest: holds its own stash at home (%s)" % _last("own_home"))
	check(await _wait(func ()->bool: return _last("host_home") != "", 20.0), "guest: in our home base")
	check(_last("host_home").begins_with("guest_mode=true held= "), "guest: empty-handed here, its stash stayed home (%s)" % _last("host_home"))
	check(_last("host_home").contains("electrician=false keeps_loot=false"), "guest: a ghost by default, keeps nothing (%s)" % _last("host_home"))
	var _guest:PlayerState = RunSession.players.get_state(1)
	check(_guest != null && !_guest.electrician, "host: guest is a ghost")
	check(await _wait(func ()->bool: return _last("alpha") != "", 10.0), "guest: saw our shotgun")
	check(is_equal_approx(float(_last("alpha")), GuestTier.GHOST_ALPHA), "guest: sees itself faint here (%s)" % _last("alpha"))
	await _wait(func ()->bool: return _puppet() != null, 5.0)
	await _frames(3)
	check(_puppet() != null && is_equal_approx((_puppet().get_node("Body") as Node2D).modulate.a, GuestTier.GHOST_ALPHA), "host: the ghost is faint here")
	check(_last("crystals_in_session") == "3", "guest: crystals still count up in the session")

	check(await _wait(func ()->bool: return _last("picked") != "", 10.0), "guest: picked up our shotgun (%s)" % _last("picked"))
	check(await _wait(func ()->bool: return _floor_count("Shotgun") == 0, 5.0), "host: the shotgun is gone from our floor")
	check(await _wait(func ()->bool: return _guest.guest_run_data != null && _guest.guest_run_data.weapons.has("Shotgun"), 5.0), "host: knows the guest holds it")

	var _grid:PistonGrid = _find(get_tree().current_scene, func (n:Node)->bool: return n is PistonGrid) as PistonGrid
	var _was_raised:bool = _grid.piston(Vector2i(6, 6)).is_raised()
	check(await _wait(func ()->bool: return _grid.row_select[6] == 1 && _grid.col_select[6] == 1, 10.0), "host: the guest's levers moved our lanes")
	check(await _wait(func ()->bool: return _last("lanes") == "1 1", 5.0), "guest: sees its levers on (%s)" % _last("lanes"))
	check(await _wait(func ()->bool: return _grid.piston(Vector2i(6, 6)).is_raised() != _was_raised && !_grid.writing, 10.0), "host: the guest's Write changed our piston")
	check(await _wait(func ()->bool: return _last("written") != "", 10.0) && _last("written") == "%s->%s" % [_was_raised, !_was_raised], "guest: saw the same write (%s)" % _last("written"))

	check(await _wait(func ()->bool: return _last("back_home") != "", 15.0), "guest: left for its own home base")
	check(await _wait(func ()->bool: return _floor_count("Shotgun") == 1, 5.0), "host: our shotgun came back to the floor")
	check(_last("back_home") == "held=Gun crystals=0", "guest: own stash back, the ghost's crystals gone (%s)" % _last("back_home"))

	# --- 2nd visit: an electrician
	check(await _wait(func ()->bool: return _last("electrician") != "", 20.0), "guest: back with a printed shell")
	check(_last("electrician") == "true keeps_loot=true alpha=1.00", "guest: an electrician, solid, keeps its loot (%s)" % _last("electrician"))
	_guest = RunSession.players.get_state(1)
	check(_guest != null && _guest.electrician, "host: the guest is an electrician")
	await _frames(5)
	check(_puppet() != null && is_equal_approx((_puppet().get_node("Body") as Node2D).modulate.a, 1.0), "host: the electrician is drawn solid")
	Net.leave()
	_finish()

func _finish()->void:
	if OS.is_process_running(_client.get("pid", -1)):
		await _wait(func ()->bool: return !OS.is_process_running(_client.pid), 10.0)
		if OS.is_process_running(_client.pid):
			OS.kill(_client.pid)
	if failures > 0:
		printerr(_read().right(3000))
		DirAccess.copy_absolute(_client.get("log", ""), ProjectSettings.globalize_path("user://coop_home_guest_last.log"))
	DirAccess.remove_absolute(_client.get("log", ""))
	var _scene:Node = get_tree().current_scene
	if _scene != null:
		_scene.queue_free()
	await _frames(4)
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	print("coop_home_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _floor_count(item:String)->int:
	var _count:int = 0
	var _scene:Node = get_tree().current_scene
	if _scene == null:
		return 0
	for _node:Node in _scene.find_children("*", "ItemPickup", true, false):
		var _pickup:ItemPickup = _node as ItemPickup
		if !_pickup.is_queued_for_deletion() && _pickup.item_resource != null && _pickup.item_resource.resource_name == item:
			_count += 1
	return _count

func _body()->Node2D:
	return Net.players.local_body()

func _puppet()->Node2D:
	var _node:Node2D = Net.players.puppets.get(1)
	return _node if _node != null && is_instance_valid(_node) else null

func _spawn_client()->Dictionary:
	var _log:String = ProjectSettings.globalize_path("user://net_client_home_%d.log" % Time.get_ticks_msec())
	var _cmd:String = "exec '%s' --headless --path '%s' res://game/tests/net_client.tscn -- 127.0.0.1:%d home > '%s' 2>&1" % [
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), PORT, _log]
	return {"pid": OS.create_process("/bin/sh", ["-c", _cmd]), "log": _log}

func _read()->String:
	return FileAccess.get_file_as_string(_client.log) if FileAccess.file_exists(_client.get("log", "")) else ""

func _last(event:String)->String:
	var _lines:PackedStringArray = _read().split("\n")
	var _prefix:String = "NETCLIENT %s " % event
	for _i:int in range(_lines.size() - 1, -1, -1):
		if _lines[_i].begins_with(_prefix):
			return _lines[_i].substr(_prefix.length()).strip_edges()
		if _lines[_i] == "NETCLIENT %s" % event.strip_edges():
			return ""
	return ""

static func _find(node:Node, test:Callable)->Node:
	if node == null:
		return null
	if test.call(node):
		return node
	for _child:Node in node.get_children():
		var _found:Node = _find(_child, test)
		if _found != null:
			return _found
	return null

func _wait(condition:Callable, seconds:float)->bool:
	var _end:int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < _end:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()

func _frames(count:int)->void:
	for _i:int in count:
		await get_tree().physics_frame
