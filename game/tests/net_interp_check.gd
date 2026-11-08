## NetInterp playback and the playtest log, without a network.
## - Positions sent at 20 Hz along a line, arriving with jitter and in bunches,
##   play back moving forward every frame (never stopping or stepping back) at
##   a steady speed, and settle on the last spot once the sender stops.
## - PlaytestLog writes events, captured engine errors and a summary to its file.
##   Godot --headless --path . res://game/tests/net_interp_check.tscn
extends Node

var failures:int = 0
var checks:int = 0

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	_check_interp(0.0, "steady")
	_check_interp(0.08, "jitter")
	_check_interp(0.15, "bad jitter")
	await _check_log()
	print("net_interp_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

## The sender walks +x at SPEED for 2 s, then stands. Arrival = send + base
## latency + up to `jitter` random extra (later packets can bunch up).
func _check_interp(jitter:float, label:String)->void:
	const SPEED:float = 60.0
	const SEND:float = 0.05
	const FRAME:float = 1.0 / 60.0
	var _rng:RandomNumberGenerator = RandomNumberGenerator.new()
	_rng.seed = 7
	# sender clock runs 1000 s ahead of ours: only differences may matter
	const CLOCK:float = 1000.0
	var _packets:Array = []
	var _sent:float = 0.0
	while _sent <= 3.0:
		var _x:float = SPEED * minf(_sent, 2.0)
		var _arrive:float = _sent + 0.04 + _rng.randf() * jitter
		_packets.append([_arrive, _sent + CLOCK, Vector2(_x, 10.0)])
		_sent += SEND
	_packets.sort_custom(func (a:Array, b:Array)->bool: return a[0] < b[0])
	var _interp:NetInterp = NetInterp.new()
	var _next:int = 0
	var _t:float = 0.0
	var _last_x:float = -INF
	var _backwards:int = 0
	var _big_steps:int = 0
	var _stopped_while_moving:int = 0
	var _walking:bool = false
	var _flips:int = 0
	while _t <= 4.0:
		while _next < _packets.size() && float(_packets[_next][0]) <= _t:
			_interp.push(_packets[_next][1], _packets[_next][2], _packets[_next][0])
			_next += 1
		var _at:Vector2 = _interp.position(_t)
		if _at.is_finite():
			if _t > 0.4 && _t < 1.9:
				if _at.x < _last_x - 0.001:
					_backwards += 1
				if _at.x - _last_x > SPEED * FRAME * 3.0:
					_big_steps += 1
				var _speed:float = _interp.velocity(_t).length()
				if _speed < NetPuppet.WALK_START:
					_stopped_while_moving += 1
			# walk / stand like NetPuppet decides it
			var _now_walking:bool = _interp.velocity(_t).length() > (NetPuppet.WALK_STOP if _walking else NetPuppet.WALK_START)
			if _now_walking != _walking:
				_flips += 1
			_walking = _now_walking
			_last_x = _at.x
		_t += FRAME
	check(_backwards == 0, "%s: never steps back (%d frames)" % [label, _backwards])
	check(_big_steps == 0, "%s: no jumps (%d frames)" % [label, _big_steps])
	check(_stopped_while_moving == 0, "%s: keeps walking between packets (%d idle frames)" % [label, _stopped_while_moving])
	# start walking once, stop once
	check(_flips <= 2, "%s: walk/stand doesn't flicker (%d changes)" % [label, _flips])
	check(is_equal_approx(_interp.position(_t).x, SPEED * 2.0), "%s: settles where the sender stopped (%s)" % [label, _interp.position(_t)])

func _check_log()->void:
	var _log:PlaytestLog = PlaytestLog.current()
	check(_log != null, "log: lives under RunSession")
	if _log == null:
		return
	var _was_on:bool = PlaytestLog.is_on()
	_log.stop()
	_log.start()
	check(PlaytestLog.is_on() && FileAccess.file_exists(_log.path), "log: file opened (%s)" % _log.path)
	PlaytestLog.event("test", {"marker": "net interp check", "value": 1.5})
	push_error("playtest log capture check")
	await get_tree().process_frame
	_log._write_stats()
	var _path:String = _log.path
	_log.stop()
	var _text:String = FileAccess.get_file_as_string(_path)
	check(_text.contains(" session start="), "log: session header")
	check(_text.contains(" test marker=\"net interp check\" value=1.50"), "log: event line")
	check(_text.contains(" error kind=error") && _text.contains("playtest log capture check") && _text.contains("net_interp_check.gd"), "log: engine error captured with its place")
	check(_text.contains(" stats fps="), "log: stats line")
	check(_text.contains(" summary ") && _text.contains("errors=1"), "log: summary counts the error")
	PlaytestLog.event("test", {"after": "stop"})
	check(!FileAccess.get_file_as_string(_path).contains("after=stop"), "log: nothing written once off")
	DirAccess.remove_absolute(_path)
	if _was_on:
		_log.start()
