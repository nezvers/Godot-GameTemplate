## Dedicated server: a headless host whose own player is hidden. Started with
##   Godot --headless --path . -- --server [--port N] [--max-players 2..8]
##                                [--save-dir PATH] [--name "Server"]
## (tools/run_server.sh). It skips the title, opens the session in its home base
## and from then on goes where the players go: their copies walk through its
## doors and exit gate like a host's teammates do. Its own player is
## server_player.tscn (Net swaps it in): the player scene with everything seen
## or used switched off, carried along and kept on the party leader
## (ServerAnchor).
##
## Victory and game over return it to the home base by themselves; so does the
## last player leaving mid-run (the run is checkpointed first).
class_name DedicatedServer
extends Node

const HOME_SCENE:String = "res://game/scenes/room_H00.tscn"
const TITLE_SCENE:String = "res://game/scenes/title.tscn"
const VICTORY_SCENE:String = "res://game/scenes/victory.tscn"
const GAME_OVER_SCENE:String = "res://addons/top_down/scenes/ui/screens/game_over.tscn"
## Seconds on the victory screen before going home (sooner once nobody follows).
const VICTORY_WAIT:float = 20.0
const GAME_OVER_WAIT:float = 8.0
const MIN_PLAYERS:int = 2

static var _options:Dictionary = {}
static var _parsed:bool

var port:int = 24565
var server_name:String = "Server"
var _scene:Node
var _scene_time:float
var _going_home:bool
## --status N: a status line every N seconds (tests, operators).
var _status_every:float
var _status_left:float

## The command line asks for a server.
static func enabled()->bool:
	return options().has("server")

## --server, --port, --max-players, --save-dir and --name from the user args.
static func options()->Dictionary:
	if _parsed:
		return _options
	_parsed = true
	var _args:PackedStringArray = OS.get_cmdline_user_args()
	var _i:int = 0
	while _i < _args.size():
		var _arg:String = _args[_i]
		if _arg == "--server":
			_options["server"] = true
		elif _arg in ["--port", "--max-players", "--save-dir", "--name", "--status"] && _i + 1 < _args.size():
			_options[_arg.trim_prefix("--")] = _args[_i + 1]
			_i += 1
		_i += 1
	return _options

## Before any save is read (RunSession._ready): the server's own save folder.
static func configure_early()->void:
	if !enabled():
		return
	var _dir:String = str(options().get("save-dir", ""))
	if _dir.is_empty():
		_dir = "user://server"
	DirAccess.make_dir_recursive_absolute(_dir)
	SaveableResource.save_dir = _dir

func _ready()->void:
	var _options_now:Dictionary = options()
	port = clampi(int(_options_now.get("port", str(Net.DEFAULT_PORT))), 1, 65535)
	server_name = Net._clean_name(str(_options_now.get("name", "Server")))
	Net.max_players = clampi(int(_options_now.get("max-players", str(Net.MAX_PLAYERS))), MIN_PLAYERS, Net.MAX_PLAYERS)
	_status_every = maxf(float(_options_now.get("status", "0")), 0.0)
	Transition.instant = true
	var _master:int = AudioServer.get_bus_index("Master")
	if _master >= 0:
		AudioServer.set_bus_mute(_master, true)
	var _local:PlayerState = RunSession.local_player()
	_local.hidden = true
	_local.display_name = server_name
	print("DedicatedServer [INFO]: port %d, up to %d players, saves in %s" % [port, Net.max_players, SaveableResource.save_dir])

func current_path()->String:
	return _scene.scene_file_path if _scene != null else ""

func _process(delta:float)->void:
	var _now:Node = get_tree().current_scene
	if _now != _scene:
		_scene = _now
		_scene_time = 0.0
		_going_home = false
		_on_scene_changed()
	_scene_time += delta
	if _status_every > 0.0:
		_status_left -= delta
		if _status_left <= 0.0:
			_status_left = _status_every
			print_status()
	match current_path():
		VICTORY_SCENE:
			if _scene_time >= VICTORY_WAIT || (_scene_time >= 3.0 && _following_guests() == 0):
				_go_home()
		GAME_OVER_SCENE:
			if _scene_time >= GAME_OVER_WAIT:
				_go_home()
		HOME_SCENE, "":
			pass
		_:
			# everyone left mid-run: keep the run and wait at home
			if Net.is_host() && _players() == 0 && _scene_time > 1.0:
				RunSession.checkpoint()
				_go_home()

func _on_scene_changed()->void:
	print("DedicatedServer [INFO]: scene ", current_path())
	_status_left = 0.0
	match current_path():
		TITLE_SCENE:
			_go_home()
		HOME_SCENE:
			if Net.state == Net.State.OFFLINE:
				var _err:Error = Net.host(port)
				print("DedicatedServer [INFO]: hosting on port %d - %s" % [port, error_string(_err)])

func _go_home()->void:
	if _going_home:
		return
	_going_home = true
	Transition.change_scene(HOME_SCENE)

## Players connected (ghosts too: they'll be back), not counting our own.
func _players()->int:
	var _count:int = 0
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local:
			_count += 1
	return _count

## Guests still in the session on the victory screen (not gone home).
func _following_guests()->int:
	var _count:int = 0
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && !_state.ghost:
			_count += 1
	return _count

## One line: room, players, the hidden player's state and where it is.
func print_status()->void:
	var _body:Node2D = Net.players.local_body()
	var _shown:bool = false
	var _layers:int = -1
	var _at:Vector2 = Vector2.ZERO
	if _body != null:
		_shown = (_body.get_node("Body") as Node2D).is_visible_in_tree()
		_layers = (_body as CollisionObject2D).collision_layer
		_at = _body.global_position
	var _leader:Node2D = ServerAnchor.leader()
	var _gap:float = _leader.global_position.distance_to(_at) if _leader != null && _body != null else -1.0
	var _hp:float = RunSession.local_player().health.hp
	print("SERVERSTATUS room=%s players=%d active=%d scaling=%d anchor_visible=%s anchor_layers=%d anchor_gap=%.1f anchor_hp=%.1f" % [
		current_path(), _players(), RunSession.players.count_active(), CoopScaling.players(), _shown, _layers, _gap, _hp])

## Everyone is down: the run ends here too (the hidden player dies for real).
func on_party_wiped()->void:
	var _body:Node2D = Net.players.local_body()
	var _anchor:ServerAnchor = _body.get_node_or_null("ServerAnchor") as ServerAnchor if _body != null else null
	if _anchor != null:
		_anchor.wipe()
