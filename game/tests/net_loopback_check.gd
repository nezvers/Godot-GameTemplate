## Co-op session over real ENet on 127.0.0.1: this process hosts, a second
## headless game (net_client.tscn) joins. Checks the handshake and slot
## assignment, the roster on both sides, a wrong-version rejection, refusal while
## the host isn't accepting, kicking, address parsing and going back offline.
##   Godot --headless --path . res://game/tests/net_loopback_check.tscn
extends Node

const PORT:int = 24599

var failures:int = 0
var checks:int = 0

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	_check_parse()
	check(Net.state == Net.State.OFFLINE && Net.is_authority(), "offline is the authority")
	check(RunSession.players.count() == 1, "offline: one local player")

	check(Net.host(PORT) == OK, "host opens the port")
	check(Net.is_host() && Net.is_online() && Net.is_authority(), "hosting state")
	check(Net.host(PORT) == ERR_ALREADY_IN_USE, "can't host twice")

	# A normal guest joins and gets slot 1
	var _ok:Dictionary = _spawn_client("ok")
	var _joined:bool = await _wait(func ()->bool: return RunSession.players.count() == 2, 10.0)
	check(_joined, "guest joined the roster")
	var _guest:PlayerState = RunSession.players.get_state(1)
	check(_guest != null && !_guest.is_local && _guest.display_name == "Client ok", "guest in slot 1 with its name")
	check(_guest != null && _guest.peer_id > 1, "guest has its peer id")
	check(_guest != null && _guest.health != RunSession.local_player().health, "guest has its own health")
	check(_guest != null && _guest.inventory != RunSession.local_player().inventory, "guest has its own inventory")
	await _wait(func ()->bool: return _read(_ok).contains("NETCLIENT roster 2"), 5.0)
	var _log:String = _read(_ok)
	check(_log.contains("NETCLIENT joined 1"), "guest sees itself in slot 1")
	check(_log.contains("NETCLIENT roster 2"), "guest sees two players")

	# A second game on this machine shares our profile (same user:// folder)
	var _twin:Dictionary = _spawn_client("sameprofile")
	var _twin_in:bool = await _wait(func ()->bool: return RunSession.players.count() == 3, 10.0)
	check(_twin_in, "a guest sharing the host's profile can join")
	var _twin_state:PlayerState = RunSession.players.get_state(2)
	check(_twin_state != null && _twin_state.profile_id != RunSession.local_player().profile_id, "shared profile keyed apart")
	if _twin_state != null:
		Net.kick(_twin_state.slot)
	await _wait(func ()->bool: return RunSession.players.count() == 2, 10.0)
	check(_read(_ok).contains("NETCLIENT sandbox false"), "a guest from another computer keeps its own progress")

	# A second copy of this very install: a blank guest that saves nothing
	var _saves_before:Dictionary = _save_times()
	var _local:Dictionary = _spawn_client("localguest")
	var _local_in:bool = await _wait(func ()->bool: return _read(_local).contains("NETCLIENT sandbox"), 10.0)
	check(_local_in, "a second copy of the game joins")
	var _local_state:PlayerState = RunSession.players.get_state(2)
	check(_local_state != null && _local_state.profile_id == "guest-local-2" && _local_state.display_name == "Guest 3", "same install: guest seat and name")
	check(_read(_local).contains("NETCLIENT sandbox true guest-local-2 meta=0 crystals=0"), "same install: blank progress on the guest")
	if _local_state != null:
		Net.kick(_local_state.slot)
	await _wait(func ()->bool: return RunSession.players.count() == 2, 10.0)
	await _wait(func ()->bool: return _read(_local).contains("NETCLIENT ended"), 5.0)
	check(_save_times() == _saves_before, "the blank guest wrote no save file")

	# A wrong version is turned away with a reason
	var _bad:Dictionary = _spawn_client("badver")
	await _wait(func ()->bool: return _read(_bad).contains("NETCLIENT failed"), 10.0)
	check(_read(_bad).contains("NETCLIENT failed Different game version"), "wrong version rejected with a reason")
	check(RunSession.players.count() == 2, "rejected guest not added")

	# Not accepting (away from the home base)
	Net.accepting = false
	var _late:Dictionary = _spawn_client("ok")
	await _wait(func ()->bool: return _read(_late).contains("NETCLIENT failed"), 10.0)
	check(_read(_late).contains("isn't in the home base"), "joining refused outside the lobby")
	Net.accepting = true

	# Kick the first guest
	if _guest != null:
		Net.kick(_guest.slot)
	var _left:bool = await _wait(func ()->bool: return RunSession.players.count() == 1, 10.0)
	check(_left, "kicked guest removed from the roster")
	await _wait(func ()->bool: return _read(_ok).contains("NETCLIENT ended"), 5.0)
	check(_read(_ok).contains("NETCLIENT ended Kicked by host"), "guest told it was kicked")

	Net.leave()
	check(Net.state == Net.State.OFFLINE && Net.is_authority(), "back offline after leaving")
	check(RunSession.players.count() == 1 && RunSession.players.local_slot == 0, "back to one local player in slot 0")
	for _client:Dictionary in [_ok, _twin, _bad, _late]:
		if OS.is_process_running(_client.pid):
			OS.kill(_client.pid)
		DirAccess.remove_absolute(_client.log)
	print("net_loopback_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check_parse()->void:
	check(Net.parse_address("1.2.3.4") == {"host": "1.2.3.4", "port": Net.DEFAULT_PORT}, "address without port uses the default")
	check(Net.parse_address(" 10.0.0.5:4000 ") == {"host": "10.0.0.5", "port": 4000}, "address with port")
	check(Net.parse_address("friend.example.org:7777").get("port", 0) == 7777, "host name with port")
	check(Net.parse_address("").is_empty(), "empty address rejected")
	check(Net.parse_address("1.2.3.4:99999").is_empty(), "port out of range rejected")
	check(Net.parse_address("1.2.3.4:abc").is_empty(), "non-numeric port rejected")
	check(Net.parse_address("a b").is_empty(), "spaces rejected")

## Launches net_client.tscn; its stdout goes to a file we poll.
## user:// save file -> modified time
func _save_times()->Dictionary:
	var _times:Dictionary = {}
	for _file:String in DirAccess.get_files_at("user://"):
		if _file.ends_with(".tres"):
			_times[_file] = FileAccess.get_modified_time("user://" + _file)
	return _times

func _spawn_client(mode:String)->Dictionary:
	var _log:String = ProjectSettings.globalize_path("user://net_client_%s_%d.log" % [mode, Time.get_ticks_msec()])
	var _cmd:String = "'%s' --headless --path '%s' res://game/tests/net_client.tscn -- 127.0.0.1:%d %s > '%s' 2>&1" % [
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), PORT, mode, _log]
	var _pid:int = OS.create_process("/bin/sh", ["-c", _cmd])
	return {"pid": _pid, "log": _log}

func _read(client:Dictionary)->String:
	return FileAccess.get_file_as_string(client.log) if FileAccess.file_exists(client.log) else ""

func _wait(condition:Callable, seconds:float)->bool:
	var _end:int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < _end:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()
