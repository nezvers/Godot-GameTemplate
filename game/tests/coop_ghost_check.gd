## Leaving and coming back (net_client.tscn, mode "ghost"), over ENet on
## 127.0.0.1; this process hosts. Checks the guest's victory choice (home with
## "I will return"), the faint copy of it walking our home base while it plays at
## its own, the rejoin portal opening onto our mission, waiting at the door during
## a fight (untouchable, held near the door), going home again mid-run with the
## run state kept here and handed back, and joining in once the walls drop.
## Save files get temp names on both sides.
##   Godot --headless --path . res://game/tests/coop_ghost_check.tscn
extends Node

const PORT:int = 24595
const HOME:String = "res://game/scenes/room_H00.tscn"
const N00:String = "res://game/scenes/room_N00.tscn"
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
	_client = _spawn_client()
	check(await _wait(func ()->bool: return _has("joined"), 30.0), "guest: joined")
	await _wait(func ()->bool: return _puppet() != null, 10.0)

	# --- victory: the guest picks home, "I will return"
	Transition.change_scene(VICTORY)
	check(await _wait(func ()->bool: return _has("menu"), 40.0), "guest: offered follow host / go home at victory")
	var _guest:PlayerState = RunSession.players.get_state(1)
	check(await _wait(func ()->bool: return _guest != null && _guest.ghost, 15.0), "host: the guest went home as a ghost")
	check(await _wait(func ()->bool: return _has("away"), 15.0) && _last("away") == "state=%d portal=true" % Net.State.GHOST, "guest: at its own home base, link kept, rejoin portal there (%s)" % _last("away"))
	check(RunSession.players.count() == 2 && RunSession.players.count_active() == 1, "host: seat kept, not counted in the fight")
	check(await _wait(func ()->bool: return _has("portal_won"), 10.0) && _last("portal_won") == "HOST WON - HEADING HOME...", "guest: the shut portal says we won (%s)" % _last("portal_won"))
	check(await _wait(func ()->bool: return _has("rewards"), 10.0) && _last("rewards") == "0", "guest: a ghost-tier ghost gets no victory weapons (%s)" % _last("rewards"))

	# --- our victory menu: home base first, the party, Main Menu asks
	var _screen:VictoryScreen = get_tree().current_scene.get_node_or_null("VictoryScreen") as VictoryScreen if get_tree().current_scene != null else null
	check(_screen != null, "host: on the victory screen")
	check(await _wait(func ()->bool:
		_resume_overlays()
		return _screen != null && _screen.menu.visible, 40.0), "host: the victory menu shows after the animation")
	if _screen != null:
		check(_screen.home_button.has_focus(), "host: Return to Home Base is the default")
		check(!_screen.upgrades_entry.visible, "host: no Upgrades while online")
		var _rows:PackedStringArray = []
		if _screen.party_list != null:
			for _label:Node in _screen.party_list.get_children():
				if !_label.is_queued_for_deletion():
					_rows.append((_label as Label).text)
		check(_rows.size() == 2 && _rows[1].contains("gone home, will return"), "host: the party list shows the ghost (%s)" % ", ".join(_rows))
		_screen.main_menu_component.button.pressed.emit()
		await _frames(2)
		check(_screen.confirm != null && is_instance_valid(_screen.confirm), "host: Main Menu asks first while a guest is linked")
		check(_current() == VICTORY, "host: still on the victory screen")
		if _screen.confirm != null:
			_screen.confirm.no_button.pressed.emit()
		await _frames(2)
		check(Net.is_host() && _current() == VICTORY, "host: Stay keeps the session")

	# --- back home: its faint copy walks our home base
	if _screen != null:
		_screen.home_button.pressed.emit()
	check(await _wait(func ()->bool: return _has("portal_home"), 30.0) && _last("portal_home") == "REJOIN HOST", "guest: its portal opens onto our home base (%s)" % _last("portal_home"))
	check(await _wait(func ()->bool: return _current() == HOME && _body() != null, 10.0), "host: home again")
	check(await _wait(func ()->bool: return _puppet() != null, 10.0), "host: the ghost's copy walks our home base")
	await _frames(3)
	check(_puppet() != null && is_equal_approx((_puppet().get_node("Body") as Node2D).modulate.a, RemotePlayer.GHOST_ALPHA), "host: drawn faint")
	check(_puppet() != null && (_puppet() as CollisionObject2D).collision_layer == 0, "host: untouchable")
	var _from:Vector2 = _puppet().global_position if _puppet() != null else Vector2.ZERO
	check(await _wait(func ()->bool: return _puppet() != null && _puppet().global_position.distance_to(_from) > 10.0, 10.0), "host: the copy follows the guest's walk")
	var _panel:PartyPanel = _find(get_tree().root, func (n:Node)->bool: return n is PartyPanel) as PartyPanel
	check(_panel != null && _panel.rows.has(1) && (_panel.rows[1].name as Label).text.contains("(at home)"), "party panel: (at home)")

	# --- on a mission, a fight on: the guest comes back through the portal
	Transition.change_scene(N00)
	check(await _wait(func ()->bool: return _current() == N00 && _body() != null, 10.0), "host: in the mission")
	check(_puppet() == null, "host: no ghost copy outside the home base")
	var _sections:Array[ArenaSection] = NetEntities._sections(get_tree().current_scene)
	check(!_sections.is_empty(), "the mission has a fight")
	var _section:ArenaSection = _sections[0] if !_sections.is_empty() else null
	if _section != null:
		_section.try_start(_body())
		_section.spawn_holds += 1
	check(await _wait(func ()->bool: return _has("portal"), 30.0) && _last("portal") == "REJOIN HOST", "guest: the portal opens onto our mission (%s)" % _last("portal"))
	check(await _wait(func ()->bool: return _has("arrived"), 20.0) && _last("arrived") == "waiting=true", "guest: arrived mid-fight, waiting at the door (%s)" % _last("arrived"))
	check(await _wait(func ()->bool: return !_guest.ghost && _guest.waiting, 10.0), "host: the guest is back, waiting")
	check(RunSession.players.count_active() == 1, "host: a waiting guest isn't in the fight yet")
	await _wait(func ()->bool: return _puppet() != null, 5.0)
	await _frames(3)
	check(_puppet() != null && (_puppet() as CollisionObject2D).collision_layer == 0, "host: the waiting copy can't be touched")
	check(await _wait(func ()->bool: return _has("leash"), 10.0) && float(_last("leash")) <= WaitingAtDoor.LEASH + 0.5, "guest: held near the door (%s)" % _last("leash"))

	# --- home again mid-run: we keep its run state
	check(await _wait(func ()->bool: return _guest.ghost && _guest.parked, 15.0), "host: guest went home mid-run, run state parked")
	check(_guest.guest_run_data != null && _guest.guest_run_data.weapons.has("Shotgun"), "host: parked state has what it carried")
	check(await _wait(func ()->bool: return _has("restored"), 30.0) && _last("restored").contains("Shotgun"), "guest: back, its weapons handed back (%s)" % _last("restored"))
	check(!_guest.parked, "host: parked state handed over")

	# --- the walls drop: it joins the fight
	check(await _wait(func ()->bool: return _guest.waiting, 10.0), "host: waiting again during the fight")
	if _section != null:
		_section.mark_cleared()
	check(await _wait(func ()->bool: return _has("released"), 15.0), "guest: joins once the walls drop")
	check(await _wait(func ()->bool: return !_guest.waiting && RunSession.players.count_active() == 2, 10.0), "host: the guest counts in the party again")
	Net.leave()
	_finish()

func _finish()->void:
	if OS.is_process_running(_client.get("pid", -1)):
		await _wait(func ()->bool: return !OS.is_process_running(_client.pid), 10.0)
		if OS.is_process_running(_client.pid):
			OS.kill(_client.pid)
	if failures > 0:
		printerr(_read().right(3000))
		DirAccess.copy_absolute(_client.get("log", ""), ProjectSettings.globalize_path("user://coop_ghost_guest_last.log"))
	DirAccess.remove_absolute(_client.get("log", ""))
	var _scene:Node = get_tree().current_scene
	if _scene != null:
		_scene.queue_free()
	await _frames(4)
	RunSave.delete_file()
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	print("coop_ghost_check: %d checks, %d failures" % [checks, failures])
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

func _spawn_client()->Dictionary:
	var _log:String = ProjectSettings.globalize_path("user://net_client_ghost_%d.log" % Time.get_ticks_msec())
	var _cmd:String = "exec '%s' --headless --path '%s' res://game/tests/net_client.tscn -- 127.0.0.1:%d ghost > '%s' 2>&1" % [
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), PORT, _log]
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
