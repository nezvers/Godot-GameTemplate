## Fresh guests joining a session already under way (net_client.tscn), over
## ENet on 127.0.0.1; this process hosts.
##   midwave:   we're mid-fight in a mission when a guest joins from its own home
##              base with two guns in its stash: it brings one, waits at the door
##              (untouchable, not counted in the fight) and joins when the walls
##              drop.
##   endscreen: we're on the victory screen when a guest joins: it stays home
##              (no run of ours to end) and follows when we Return to Home Base.
## Save files get temp names on both sides.
##   Godot --headless --path . res://game/tests/coop_join_check.tscn
extends Node

const PORT:int = 24597
const HOME:String = "res://game/scenes/room_H00.tscn"
const N01:String = "res://game/scenes/room_N01.tscn"
const VICTORY:String = "res://game/scenes/victory.tscn"

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
	check(Net.host(PORT) == OK, "host: open to friends")

	# --- midwave: a fight is on when the guest joins
	Transition.change_scene(N01)
	check(await _wait(func ()->bool: return _current() == N01 && _body() != null, 10.0), "host: in the mission")
	var _sections:Array[ArenaSection] = NetEntities._sections(get_tree().current_scene)
	var _section:ArenaSection = null
	await _frames(5)
	for _candidate:ArenaSection in _sections:
		if _section == null && !_candidate.waves.is_empty() && !_candidate.is_cleared:
			_section = _candidate
	check(_section != null, "the mission has a fight (%s)" % ", ".join(_sections.map(func (a:ArenaSection)->String: return "%s waves=%d cleared=%s" % [a.name, a.waves.size(), a.is_cleared])))
	if _section != null:
		_section.try_start(_body())
		_section.spawn_holds += 1
	check(await _wait(func ()->bool: return _section != null && _section.fight_active, 5.0), "host: the fight is on (%s)" % ("cleared=%s waves=%d sections=%d" % [_section.is_cleared, _section.waves.size(), _sections.size()] if _section != null else "-"))
	_client = _spawn_client("midwave")
	check(await _wait(func ()->bool: return _has("home"), 30.0) && _last("home") == "Shotgun,Water Gun", "guest: two guns in hand at its home (%s)" % _last("home"))
	check(await _wait(func ()->bool: return _has("arrived"), 30.0) && _last("arrived") == "room=room_N01.tscn waiting=true held=Shotgun", "guest: arrived mid-fight, waiting, one gun along (%s)" % _last("arrived"))
	check(await _wait(func ()->bool: return _has("stash"), 5.0) && _last("stash") == "Shotgun,Water Gun", "guest: a ghost-tier guest's stash stays whole (%s)" % _last("stash"))
	var _guest:PlayerState = RunSession.players.get_state(1)
	check(await _wait(func ()->bool: return _guest != null && _guest.waiting, 10.0), "host: the new guest waits")
	check(RunSession.players.count() == 2 && RunSession.players.count_active() == 1, "host: a waiting guest isn't in the fight (scaling, wipe check)")
	check(_guest != null && _guest.guest_run_data != null, "host: the guest's run state came in right away")
	await _wait(func ()->bool: return _puppet() != null, 5.0)
	await _frames(3)
	check(_puppet() != null && (_puppet() as CollisionObject2D).collision_layer == 0, "host: the waiting copy can't be touched")
	await get_tree().create_timer(1.0).timeout
	check(_guest != null && _guest.waiting && !_has("released"), "guest: still waiting while the fight is on")
	if _section != null:
		_section.mark_cleared()
	check(await _wait(func ()->bool: return _has("released"), 15.0), "guest: joins once the walls drop")
	check(await _wait(func ()->bool: return _guest != null && !_guest.waiting && RunSession.players.count_active() == 2, 10.0), "host: the guest counts in the party")
	Net.kick(1)
	check(await _wait(func ()->bool: return _has("ended"), 15.0) && RunSession.players.count() == 1, "host: the guest is gone")
	await _end_client()

	# --- endscreen: we've won when the guest joins
	Transition.change_scene(VICTORY)
	check(await _wait(func ()->bool: return _current() == VICTORY, 10.0), "host: on the victory screen")
	var _screen:VictoryScreen = get_tree().current_scene.get_node_or_null("VictoryScreen") as VictoryScreen
	_client = _spawn_client("endscreen")
	check(await _wait(func ()->bool: return _has("held_back"), 40.0) && _last("held_back") == "room=room_H00.tscn wait=victory.tscn", "guest: stays at its home while we're on the victory screen (%s)" % _last("held_back"))
	check(await _wait(func ()->bool:
		_resume_overlays()
		return _screen != null && _screen.menu.visible, 40.0), "host: the victory menu shows")
	await get_tree().create_timer(0.5).timeout
	check(!_has("followed"), "guest: not pulled onto our victory screen")
	if _screen != null:
		_screen.home_button.pressed.emit()
	check(await _wait(func ()->bool: return _current() == HOME && _body() != null, 10.0), "host: Return to Home Base")
	check(await _wait(func ()->bool: return _has("followed"), 30.0) && _last("followed") == "room=room_H00.tscn guest_mode=true", "guest: follows into our home base (%s)" % _last("followed"))
	Net.leave()
	await _end_client()
	_finish()

func _end_client()->void:
	if OS.is_process_running(_client.get("pid", -1)):
		await _wait(func ()->bool: return !OS.is_process_running(_client.pid), 10.0)
		if OS.is_process_running(_client.pid):
			OS.kill(_client.pid)
	if failures > 0:
		printerr(_read().right(3000))
		DirAccess.copy_absolute(_client.get("log", ""), ProjectSettings.globalize_path("user://coop_join_guest_last.log"))
	DirAccess.remove_absolute(_client.get("log", ""))

func _finish()->void:
	var _scene:Node = get_tree().current_scene
	if _scene != null:
		_scene.queue_free()
	await _frames(4)
	RunSave.delete_file()
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	print("coop_join_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

## The victory animation holds at its pause marker for a click.
func _resume_overlays()->void:
	for _node:Node in get_tree().root.find_children("*", "Node2D", true, false):
		if _node.has_method("resume") && _node.has_signal("paused"):
			_node.call("resume")

func _body()->Node2D:
	return Net.players.local_body()

func _puppet()->Node2D:
	var _node:Node2D = Net.players.puppets.get(1)
	return _node if _node != null && is_instance_valid(_node) else null

func _current()->String:
	var _scene:Node = get_tree().current_scene
	return _scene.scene_file_path if _scene != null else ""

func _spawn_client(mode:String)->Dictionary:
	var _log:String = ProjectSettings.globalize_path("user://net_client_%s_%d.log" % [mode, Time.get_ticks_msec()])
	var _cmd:String = "exec '%s' --headless --path '%s' res://game/tests/net_client.tscn -- 127.0.0.1:%d %s > '%s' 2>&1" % [
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), PORT, mode, _log]
	return {"pid": OS.create_process("/bin/sh", ["-c", _cmd]), "log": _log}

func _read()->String:
	return FileAccess.get_file_as_string(_client.log) if FileAccess.file_exists(_client.get("log", "")) else ""

func _has(event:String)->bool:
	return _read().contains("NETCLIENT %s " % event) || _read().contains("NETCLIENT %s\n" % event)

func _last(event:String)->String:
	var _lines:PackedStringArray = _read().split("\n")
	var _prefix:String = "NETCLIENT %s " % event
	for _i:int in range(_lines.size() - 1, -1, -1):
		if _lines[_i].begins_with(_prefix):
			return _lines[_i].substr(_prefix.length()).strip_edges()
	return ""

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
