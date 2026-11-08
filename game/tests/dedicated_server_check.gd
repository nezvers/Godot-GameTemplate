## A dedicated server (a second headless game started with --server, its saves
## in a temp folder) and this process as a player joining it from its own home
## base. Checks that the server shows nobody of its own (no copy, no party panel
## row), counts only real players for scaling, and that the hidden player is
## invisible, untouchable, never hurt and kept on the player; that walking onto
## the exit gate takes the server (and so us) to the mission; and that the
## server's saves land in its own folder.
##   Godot --headless --path . res://game/tests/dedicated_server_check.tscn
extends Node

const PORT:int = 24597
const TD:String = "res://addons/top_down/"
const HOME:String = "res://game/scenes/room_H00.tscn"
const N00:String = "res://game/scenes/room_N00.tscn"

var failures:int = 0
var checks:int = 0
var _server:Dictionary
var _saved_names:Dictionary = {}
var _save_dir:String

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	# our home base saves while we're in it: keep the user's file out of it
	for _path:String in ["res://game/resources/home_base_resource.tres", "res://game/resources/campaign_resource.tres"]:
		var _resource:SaveableResource = load(_path)
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name += "_test"
		_resource.delete_resource()
		_resource.reset_resource()
	# another computer as far as the server can tell
	GuestSandbox.install_override = "dedicated_check"
	RunSession.profile.profile_id = "dedicated_check_%d" % OS.get_process_id()
	RunSession.local_player().profile_id = RunSession.profile.profile_id
	Transition.instant = true
	get_tree().current_scene = null
	_run.call_deferred()

func _run()->void:
	_save_dir = ProjectSettings.globalize_path("user://dedicated_check_%d" % OS.get_process_id())
	_server = _spawn_server()
	Transition.change_scene(HOME)
	check(await _wait(func ()->bool: return _body() != null, 10.0), "player: in our home base")
	check(await _wait(func ()->bool: return _read().contains("hosting on port %d - OK" % PORT), 60.0), "server: up and hosting from its home base")
	var _err:Error = Net.join("127.0.0.1:%d" % PORT)
	check(_err == OK, "player: connecting")
	check(await _wait(func ()->bool: return Net.is_guest() && _current() == HOME && _body() != null, 20.0), "player: joined, in the server's home base")
	check(Net.host_is_server, "player: knows it's a dedicated server")
	check(RunSession.players.local_slot == 1, "player: first seat after the server's (%d)" % RunSession.players.local_slot)
	check(RunSession.players.count() == 1 && RunSession.players.get_state(0) == null, "player: the server's own player isn't in our roster")
	await _frames(30)
	check(Net.players.puppets.is_empty(), "player: no copy of the server's player in the room")
	var _panel:PartyPanel = _find(get_tree().root, func (n:Node)->bool: return n is PartyPanel) as PartyPanel
	check(_panel == null || _panel.rows.is_empty(), "player: no party panel row for the server")
	check((_body().get_node("Body/Stretch/Sprite2D") as Sprite2D).texture == PlayerSkin.GUEST_TEXTURE, "player: wears the electrician (no visible host)")

	# the hidden player sits on us and is untouchable
	_body().global_position += Vector2(24, 8)
	check(await _wait(func ()->bool: return _status().contains("anchor_gap=") && float(_field("anchor_gap")) >= 0.0 && float(_field("anchor_gap")) < 4.0, 10.0), "server: hidden player follows us (%s)" % _field("anchor_gap"))
	check(_field("anchor_visible") == "false", "server: hidden player is invisible")
	check(_field("anchor_layers") == "0", "server: hidden player has no collision layer (doors, enemies, loot ignore it)")
	check(_field("players") == "1" && _field("active") == "1" && _field("scaling") == "1", "server: scales for one player (%s)" % _status())

	# onto the exit gate: the server departs and we follow
	var _gate:HomeExitGate = _find(get_tree().current_scene, func (n:Node)->bool: return n is HomeExitGate) as HomeExitGate
	check(_gate != null, "home base has its exit gate")
	if _gate != null:
		while _body().get_node("ResourceNode").get_resource("weapons").list.size() > 1:
			_body().get_node("ResourceNode").get_resource("weapons").list.pop_back()
		_body().global_position = _gate.global_position
	check(await _wait(func ()->bool: return _read().contains("scene " + N00), 20.0), "server: our walking onto the gate took it to the mission")
	check(await _wait(func ()->bool: return _current() == N00 && _body() != null, 20.0), "player: followed the server to the mission")
	check(await _wait(func ()->bool: return _field("room") == N00 && float(_field("anchor_gap")) >= 0.0 && float(_field("anchor_gap")) < 4.0, 10.0), "server: hidden player carried to the mission and on us")
	check(float(_field("anchor_hp")) > 0.0, "server: hidden player unhurt")

	check(FileAccess.file_exists(_save_dir.path_join("Profile.tres")), "server: saves in its own folder")
	check(!FileAccess.file_exists("user://Profile_server.tres"), "server: nothing extra in the user folder")
	_finish()

func _finish()->void:
	Net.players.leaving_by_choice = true
	Net.leave()
	if OS.is_process_running(_server.get("pid", -1)):
		OS.kill(_server.pid)
	if failures > 0:
		printerr(_read().right(4000))
	DirAccess.remove_absolute(_server.get("log", ""))
	_remove_dir(_save_dir)
	var _scene:Node = get_tree().current_scene
	if _scene != null:
		_scene.queue_free()
	await _frames(4)
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	print("dedicated_server_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

static func _remove_dir(path:String)->void:
	if !DirAccess.dir_exists_absolute(path):
		return
	for _file:String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(_file))
	DirAccess.remove_absolute(path)

func _spawn_server()->Dictionary:
	var _log:String = ProjectSettings.globalize_path("user://dedicated_server_%d.log" % Time.get_ticks_msec())
	var _cmd:String = "exec '%s' --headless --path '%s' -- --server --port %d --save-dir '%s' --status 0.5 > '%s' 2>&1" % [
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), PORT, _save_dir, _log]
	return {"pid": OS.create_process("/bin/sh", ["-c", _cmd]), "log": _log}

func _read()->String:
	return FileAccess.get_file_as_string(_server.log) if FileAccess.file_exists(_server.get("log", "")) else ""

## The server's latest status line.
func _status()->String:
	var _lines:PackedStringArray = _read().split("\n")
	for _i:int in range(_lines.size() - 1, -1, -1):
		if _lines[_i].begins_with("SERVERSTATUS "):
			return _lines[_i]
	return ""

func _field(key:String)->String:
	for _part:String in _status().split(" "):
		if _part.begins_with(key + "="):
			return _part.substr(key.length() + 1)
	return ""

func _body()->Node2D:
	return Net.players.local_body()

func _current()->String:
	var _scene:Node = get_tree().current_scene
	return _scene.scene_file_path if _scene != null else ""

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
