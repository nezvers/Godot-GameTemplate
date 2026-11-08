## Playtest log: everything a tester's session needs to be looked at later, in
## one plain text file to share (user://logs/playtest_<date>.log).
##
## Off by default. On with the "Playtest log" box in the co-op dialog (saved in
## NetSettings) or the --playtest-log launch argument. One line per event:
##   <wall clock> <session seconds> p<peer> <category> key=value ...
## Categories: session, net, room, fight, player, loot, stats, error, summary.
## Engine errors and warnings (with script backtraces) are copied in too, so the
## file alone shows what went wrong. Every STATS_INTERVAL a stats line has fps,
## link health per peer (NetStats), entities, hp and loot counters.
##
## Lives under RunSession as /root/RunSession/PlaytestLog; PlaytestLog.event()
## does nothing while it's off.
class_name PlaytestLog
extends Node

const DIR:String = "user://logs"
const PREFIX:String = "playtest_"
const KEEP_FILES:int = 10
const STATS_INTERVAL:float = 3.0
const SETTINGS_PATH:String = "res://game/resources/net_settings.tres"
const CLI_FLAG:String = "--playtest-log"
const LOOT_COUNTERS:PackedStringArray = ["coin", "meat", "slime", "boss_crystal"]

static var _instance:PlaytestLog

var path:String
var _file:FileAccess
var _mutex:Mutex = Mutex.new()
var _logger:_Capture
var _started_usec:int
var _stats_left:float
var _frame_count:int
var _frame_time_sum:float
var _frame_time_max:float
var _scene:Node
## Totals for the summary.
var _totals:Dictionary = {"hits": 0, "damage_dealt": 0.0, "kills": 0, "damage_taken": 0.0, "rooms": 0, "errors": 0, "warnings": 0}

## Engine errors and warnings (any thread) into the file.
class _Capture extends Logger:
	var owner_log:PlaytestLog

	func _log_error(function:String, file:String, line:int, code:String, rationale:String, _editor_notify:bool, error_type:int, script_backtraces:Array[ScriptBacktrace])->void:
		if owner_log == null:
			return
		var _kind:String = "warning" if error_type == ERROR_TYPE_WARNING else "error"
		var _text:String = rationale if !rationale.is_empty() else code
		var _lines:PackedStringArray = ["%s:%d @ %s(): %s" % [file, line, function, _text]]
		for _backtrace:ScriptBacktrace in script_backtraces:
			for _i:int in _backtrace.get_frame_count():
				_lines.append("    at %s:%d %s()" % [_backtrace.get_frame_file(_i), _backtrace.get_frame_line(_i), _backtrace.get_frame_function(_i)])
		owner_log._write_raw("error", {"kind": _kind, "text": "\n".join(_lines)}, _kind)

	func _log_message(message:String, error:bool)->void:
		# printerr only: plain prints stay out (noise)
		if owner_log != null && error:
			owner_log._write_raw("error", {"kind": "stderr", "text": message.strip_edges()}, "warning")

## True while a log file is being written.
static func is_on()->bool:
	return _instance != null && _instance._file != null

## One event line (no-op while off). Values are written with str().
static func event(category:String, data:Dictionary = {})->void:
	if is_on():
		_instance._write_raw(category, data, "")

## The running log, if any.
static func current()->PlaytestLog:
	return _instance

func _ready()->void:
	name = "PlaytestLog"
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _wanted():
		start()

func _wanted()->bool:
	if OS.get_cmdline_user_args().has(CLI_FLAG) || OS.get_cmdline_args().has(CLI_FLAG):
		return true
	var _settings:NetSettings = load(SETTINGS_PATH)
	_settings.load_resource()
	return _settings.playtest_log

## The co-op dialog's box: starts or stops a log right away.
func set_enabled(value:bool)->void:
	if value && _file == null:
		start()
	elif !value && _file != null:
		stop()

func start()->void:
	if _file != null:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	_prune()
	var _stamp:String = Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace(" ", "_")
	path = "%s/%s%s.log" % [DIR, PREFIX, _stamp]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		path = ""
		return
	_started_usec = Time.get_ticks_usec()
	for _key:String in _totals:
		_totals[_key] = 0 if _totals[_key] is int else 0.0
	_write_raw("session", {
		"start": Time.get_datetime_string_from_system(),
		"game_version": ProjectSettings.get_setting("application/config/version", "dev"),
		"godot": Engine.get_version_info().get("string", ""),
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"cpu": OS.get_processor_name(),
		"display": DisplayServer.get_name(),
		"name": RunSession.profile.display_name if RunSession.profile != null else "",
		"profile": RunSession.profile.profile_id if RunSession.profile != null else "",
	}, "")
	_logger = _Capture.new()
	_logger.owner_log = self
	OS.add_logger(_logger)
	_connect_signals()
	_log_net_state()

func stop()->void:
	if _file == null:
		return
	_write_summary()
	if _logger != null:
		OS.remove_logger(_logger)
		_logger.owner_log = null
		_logger = null
	_disconnect_signals()
	_mutex.lock()
	_file.close()
	_file = null
	_mutex.unlock()

func _exit_tree()->void:
	stop()
	if _instance == self:
		_instance = null

func _notification(what:int)->void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST || what == NOTIFICATION_PREDELETE:
		stop()

func _prune()->void:
	var _files:Array = Array(DirAccess.get_files_at(DIR)).filter(func (f:String)->bool: return f.begins_with(PREFIX) && f.ends_with(".log"))
	_files.sort()
	while _files.size() >= KEEP_FILES:
		DirAccess.remove_absolute("%s/%s" % [DIR, _files.pop_front()])

# --- Writing ------------------------------------------------------------------

func _write_raw(category:String, data:Dictionary, counted:String)->void:
	_mutex.lock()
	if _file == null:
		_mutex.unlock()
		return
	if counted == "error":
		_totals.errors += 1
	elif counted == "warning":
		_totals.warnings += 1
	var _parts:PackedStringArray = []
	for _key:Variant in data:
		var _value:String = _format(data[_key])
		if _value.contains(" ") || _value.contains("\n") || _value.is_empty():
			_value = "\"%s\"" % _value.replace("\"", "'")
		_parts.append("%s=%s" % [_key, _value])
	var _seconds:float = (Time.get_ticks_usec() - _started_usec) / 1000000.0
	var _clock:String = Time.get_time_string_from_system()
	var _peer:int = _peer_id()
	_file.store_line("%s %9.3f p%d %s %s" % [_clock, _seconds, _peer, category, " ".join(_parts)])
	_file.flush()
	_mutex.unlock()

static func _format(value:Variant)->String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.2f" % value
		TYPE_VECTOR2:
			return "%.1f,%.1f" % [value.x, value.y]
	return str(value)

## Safe from any thread: no multiplayer calls off the main thread.
func _peer_id()->int:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return -1
	return Net.local_peer_id() if Net.is_linked() else 0

# --- What gets logged ---------------------------------------------------------------

func _connect_signals()->void:
	_link(Net.state_changed, _log_net_state)
	_link(Net.roster_changed, _log_roster)
	_link(Net.connection_failed, _on_connection_failed)
	_link(Net.session_ended, _on_session_ended)
	_link(multiplayer.peer_connected, _on_peer_connected)
	_link(multiplayer.peer_disconnected, _on_peer_disconnected)
	_link(RunSession.players.player_downed, _on_player_downed)
	_link(RunSession.players.all_downed, _on_all_downed)

func _disconnect_signals()->void:
	for _pair:Array in _links:
		if (_pair[0] as Signal).is_connected(_pair[1]):
			(_pair[0] as Signal).disconnect(_pair[1])
	_links.clear()

var _links:Array = []

func _link(sig:Signal, callable:Callable)->void:
	if !sig.is_connected(callable):
		sig.connect(callable)
		_links.append([sig, callable])

func _log_net_state()->void:
	event("net", {"state": Net.State.keys()[Net.state], "session": Net.session_id, "port": Net.port})

func _log_roster()->void:
	var _list:PackedStringArray = []
	for _state:PlayerState in RunSession.players.all():
		_list.append("%d:%s:peer%d%s%s" % [_state.slot, _state.display_name.replace(" ", "_"), _state.peer_id, ":local" if _state.is_local else "", ":electrician" if _state.electrician else ""])
	event("net", {"roster": ",".join(_list)})

func _on_connection_failed(reason:String)->void:
	event("net", {"connection_failed": reason})

func _on_session_ended(reason:String)->void:
	event("net", {"session_ended": reason})

func _on_peer_connected(peer:int)->void:
	event("net", {"peer_connected": peer, "address": Net.peer_address(peer) if Net.is_host() else ""})

func _on_peer_disconnected(peer:int)->void:
	event("net", {"peer_disconnected": peer})

func _on_player_downed(state:PlayerState)->void:
	event("player", {"slot": state.slot, "name": state.display_name, "downed": state.downed})

func _on_all_downed()->void:
	event("player", {"party_wiped": true})

## NetEntities.on_points, for every hit landing anywhere on this machine.
static func hit(damage:DamageResource, points:float, critical:bool)->void:
	if !is_on() || damage.owner == null || !is_instance_valid(damage.owner):
		return
	var _log:PlaytestLog = _instance
	var _body:Node = Net.players.local_body()
	if damage.owner == _body:
		_log._totals.damage_taken += points
		event("player", {"hurt": points, "critical": critical})
		return
	if damage.owner.is_in_group(&"remote_player"):
		return
	_log._totals.hits += 1
	_log._totals.damage_dealt += points
	var _resources:ResourceNode = damage.owner.get_node_or_null("ResourceNode")
	var _health:HealthResource = _resources.get_resource("health") if _resources != null else null
	if _health != null && _health.is_dead:
		_log._totals.kills += 1
		event("fight", {"kill": damage.owner.name, "at": (damage.owner as Node2D).global_position if damage.owner is Node2D else Vector2.ZERO})

func _process(delta:float)->void:
	if _file == null:
		return
	_frame_count += 1
	_frame_time_sum += delta
	_frame_time_max = maxf(_frame_time_max, delta)
	var _now:Node = get_tree().current_scene
	if _now != _scene:
		_scene = _now
		_on_room_changed()
	_stats_left -= delta
	if _stats_left <= 0.0:
		_stats_left = STATS_INTERVAL
		_write_stats()

func _on_room_changed()->void:
	if _scene == null:
		return
	_totals.rooms += 1
	event("room", {"enter": _scene.scene_file_path})
	for _section:ArenaSection in NetEntities._sections(_scene):
		var _path:String = str(_scene.get_path_to(_section))
		_section.fight_started.connect(func ()->void: event("fight", {"start": _path, "wave": _section.wave_index}))
		_section.cleared.connect(func ()->void: event("fight", {"cleared": _path}))

func _write_stats()->void:
	var _fps:float = _frame_count / maxf(_frame_time_sum, 0.001)
	var _data:Dictionary = {
		"fps": _fps,
		"worst_frame_ms": _frame_time_max * 1000.0,
		"room": _scene.scene_file_path.get_file().get_basename() if _scene != null else "",
	}
	_frame_count = 0
	_frame_time_sum = 0.0
	_frame_time_max = 0.0
	var _local:PlayerState = RunSession.local_player()
	_data["hp"] = "%d/%d" % [roundi(_local.health.hp), roundi(_local.health.max_hp)]
	_data["weapon"] = _local.active_weapon_name()
	var _body:Node2D = Net.players.local_body()
	if _body != null:
		_data["pos"] = _body.global_position
	for _id:String in LOOT_COUNTERS:
		var _counter:ScoreResource = LootItems.counter(_id)
		if _counter != null:
			_data[_id] = _counter.value
	_data["enemies"] = ActiveEnemy.active_instances.size()
	if Net.is_online():
		_data["net_entities"] = Net.entities.entities.size()
		for _peer:int in Net.stats.peers():
			var _link_stats:Dictionary = Net.stats.link(_peer)
			_data["peer%d" % _peer] = "rtt=%dms,health=%d%%,jitter=%dms,enet_rtt=%dms,enet_loss=%.1f%%" % [
				roundi(float(_link_stats.get("rtt_ms", -1.0))), roundi(float(_link_stats.get("health", 0.0)) * 100.0),
				roundi(float(_link_stats.get("jitter_ms", 0.0))), int(_link_stats.get("enet_rtt_ms", -1)),
				float(_link_stats.get("enet_loss", 0.0)) * 100.0]
		for _state:PlayerState in RunSession.players.all():
			if !_state.is_local:
				_data["slot%d" % _state.slot] = "%s,%s,hp=%d,%s" % [_state.display_name.replace(" ", "_"), _state.room_scene.get_file().get_basename(), roundi(_state.health.hp), "down" if _state.downed else "up"]
	event("stats", _data)

func _write_summary()->void:
	var _data:Dictionary = _totals.duplicate()
	_data["seconds"] = (Time.get_ticks_usec() - _started_usec) / 1000000.0
	_write_raw("summary", _data, "")
