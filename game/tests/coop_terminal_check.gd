## Home base Comms Terminal: placed by the builder, opens the co-op dialog,
## freezes the player's input while it is open (typing an address must not walk
## or shoot), Escape closes it without opening the pause menu, and hosting from
## the dialog lights the terminal and switches to the Session tab: addresses to
## share with Copy, the player list with Kick for a real joining guest.
##   Godot --headless --path . res://game/tests/coop_terminal_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const HOME:String = "res://game/scenes/room_H00.tscn"
const PORT:int = 24598

var failures:int = 0
var checks:int = 0
var _saved_names:Dictionary = {}
var _room:Node

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	var _home:HomeBaseResource = load("res://game/resources/home_base_resource.tres")
	var _settings:NetSettings = load("res://game/resources/net_settings.tres")
	for _resource:SaveableResource in [_home, _settings]:
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name = _resource.resource_name + "_test"
		_resource.delete_resource()
	_settings.reset_resource()

	_room = (load(HOME) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)
	var _terminal:Node2D = _room.get_node_or_null("WallLayer_Ysorted/CommsTerminal1")
	check(_terminal != null, "comms terminal placed in the home base")
	var _player:Node2D = (load(TD + "resources/ReferenceNodeResources/player_reference.tres") as ReferenceNodeResource).node
	check(_player != null, "player spawned")
	if _terminal == null || _player == null:
		_finish()
		return
	var _sprite:Sprite2D = _terminal.get_node("Visuals/Sprite2D")
	check(_sprite.frame == 0, "terminal screen dark while offline")

	_terminal.try_use()
	await _frames(2)
	var _layer:Node = get_tree().root.get_node_or_null("CoopDialogLayer")
	check(_layer != null && _layer.get_child_count() == 1, "using the terminal opens the dialog")
	var _input:PlayerInput = _player.get_node("PlayerInput")
	check(!_input.enabled, "player input frozen while the dialog is open")
	check(_terminal.busy, "terminal busy while its dialog is open")

	# Host from the dialog
	var _dialog:Control = _layer.get_child(0)
	_dialog._port_edit.text = str(PORT)
	_dialog._on_host_pressed()
	await _frames(2)
	check(Net.is_host(), "dialog Host opens the session")
	check(_sprite.frame == 1, "terminal screen lit while hosting")
	var _tabs:TabContainer = _dialog._tabs
	check(_tabs.current_tab == _dialog.Tab.SESSION, "hosting opens the Session tab")
	check(!_tabs.is_tab_hidden(_dialog.Tab.SESSION), "Session tab shown while hosting")
	check(_tabs.is_tab_hidden(_dialog.Tab.HOST) && _tabs.is_tab_hidden(_dialog.Tab.JOIN), "Host and Join tabs hidden while hosting")
	check(_dialog._roster.get_child_count() == 1, "Session lists the host")
	check(_text_of(_dialog._roster).contains("(host, you)"), "host marked as host and you")
	check(_dialog._status.text.begins_with("Hosting on port %d" % PORT), "dialog shows the hosting status")
	var _shared:bool = await _wait(func ()->bool: return !Net.share_addresses.is_empty(), 15.0)
	check(_shared, "share addresses looked up")
	await _frames(2)
	var _share_text:String = _text_of(_dialog._share)
	check(_share_text.contains("Join"), "Session explains what the friend does")
	check(_share_text.contains("127.0.0.1:%d" % PORT), "Session shows the same-computer address")
	check(_count_buttons(_dialog._share, "Copy") == Net.share_addresses.size(), "every address has a Copy button")

	# A friend joins: listed with a Kick button, kicking removes them
	var _client:Dictionary = _spawn_client()
	var _joined:bool = await _wait(func ()->bool: return RunSession.players.count() == 2, 10.0)
	check(_joined, "friend joined")
	await _frames(2)
	check(_dialog._roster.get_child_count() == 2, "Session lists the friend")
	check(_dialog._players_title.text == "Players 2/%d" % Net.MAX_PLAYERS, "player count shown")
	var _kick:Button = _dialog._roster.find_child("Kick1", true, false) as Button
	check(_kick != null, "friend has a Kick button")
	check(_count_buttons(_dialog._roster, "Kick") == 1, "no Kick button on the host")
	if _kick != null:
		_kick.pressed.emit()
	var _gone:bool = await _wait(func ()->bool: return RunSession.players.count() == 1, 10.0)
	check(_gone, "Kick removes the friend")
	await _frames(2)
	check(_dialog._roster.get_child_count() == 1, "Session list updated after the kick")
	if OS.is_process_running(_client.pid):
		OS.kill(_client.pid)
	DirAccess.remove_absolute(_client.log)

	# Escape closes the dialog, not into the pause menu
	var _pause:BoolResource = load(TD + "resources/global_resources/pause_resource.tres")
	var _escape:InputEventAction = InputEventAction.new()
	_escape.action = &"ui_cancel"
	_escape.pressed = true
	Input.parse_input_event(_escape)
	var _release:InputEventAction = InputEventAction.new()
	_release.action = &"ui_cancel"
	_release.pressed = false
	Input.parse_input_event(_release)
	await _frames(4)
	check(get_tree().root.get_node_or_null("CoopDialogLayer") == null, "Escape closes the dialog")
	check(!_pause.value, "Escape didn't open the pause menu")
	check(_input.enabled, "player input back after closing")
	check(!_terminal.busy, "terminal usable again")
	check(Net.is_host(), "closing the dialog keeps the session open")

	# Reopened while hosting: straight to the Session tab
	_terminal.try_use()
	await _frames(2)
	var _again:Control = get_tree().root.get_node("CoopDialogLayer").get_child(0)
	check(_again._tabs.current_tab == _again.Tab.SESSION, "reopened dialog shows the Session tab")
	_again._on_leave_pressed()
	await _frames(2)
	check(_again._tabs.is_tab_hidden(_again.Tab.SESSION), "Session tab hidden after leaving")
	check(!_again._tabs.is_tab_hidden(_again.Tab.HOST) && _again._tabs.current_tab == _again.Tab.HOST, "back to the Host tab after leaving")
	_again.close()
	await _frames(2)
	check(_sprite.frame == 0, "terminal dark again after leaving")
	_finish()

func _finish()->void:
	if Net.state != Net.State.OFFLINE:
		Net.leave()
	if _room != null:
		_room.queue_free()
		await _frames(3)
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	print("coop_terminal_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _text_of(node:Node)->String:
	var _text:String = ""
	if node is Label or node is Button:
		_text += node.text + "\n"
	for _child:Node in node.get_children():
		if !_child.is_queued_for_deletion():
			_text += _text_of(_child)
	return _text

func _count_buttons(node:Node, text:String)->int:
	var _count:int = 1 if node is Button && node.text == text && !node.is_queued_for_deletion() else 0
	for _child:Node in node.get_children():
		_count += _count_buttons(_child, text)
	return _count

func _spawn_client()->Dictionary:
	var _log:String = ProjectSettings.globalize_path("user://net_client_terminal_%d.log" % Time.get_ticks_msec())
	var _cmd:String = "'%s' --headless --path '%s' res://game/tests/net_client.tscn -- 127.0.0.1:%d ok > '%s' 2>&1" % [
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), PORT, _log]
	return {"pid": OS.create_process("/bin/sh", ["-c", _cmd]), "log": _log}

func _wait(condition:Callable, seconds:float)->bool:
	var _end:int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < _end:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().process_frame
