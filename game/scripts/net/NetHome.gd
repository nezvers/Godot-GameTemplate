## The host's home base as guests see it: the piston memory grid with its lane
## levers, data and gate levers (what lies on the floor goes through
## NetEntities). Lives under the Net autoload as /root/Net/Home.
##
## A guest pressing a shared contraption (Interactable.is_shared_online) asks the
## host to press it (_use_request, by node path: rooms match on every machine);
## the host runs it and sends the grid's state to every guest in its home base
## (_grid_state), plus a heads-up before a write so the ripple plays there too.
class_name NetHome
extends Node

const HOME_SCENE:String = "res://game/scenes/room_H00.tscn"
const GRID_REFERENCE_PATH:String = "res://addons/top_down/resources/ReferenceNodeResources/piston_grid_reference.tres"
const MAX_PATH:int = 200
## Flood guard on a guest's presses: a burst of USE_BURST, then USE_RATE a
## second (each contraption has its own use cooldown on top).
const USE_BURST:float = 6.0
const USE_RATE:float = 8.0

var _grid_reference:ReferenceNodeResource
## Host: the grid we listen to, and guests (peer id) already sent its state.
var _grid:PistonGrid
var _sent_to:Dictionary = {}
var _state_queued:bool
## Host: peer id -> [presses left, msec of the last refill].
var _use_tokens:Dictionary = {}

func net()->Node:
	return get_parent()

func _ready()->void:
	_grid_reference = load(GRID_REFERENCE_PATH)

func _physics_process(_delta:float)->void:
	if !net().is_host():
		_sent_to.clear()
		return
	var _now:PistonGrid = _current_grid()
	if _now != _grid:
		_watch(_now)
	if _grid == null:
		return
	for _state:PlayerState in _guests_home():
		if !_sent_to.has(_state.peer_id):
			_sent_to[_state.peer_id] = true
			_grid_state.rpc_id(_state.peer_id, _grid_snapshot())

func _current_grid()->PistonGrid:
	var _node:Object = _grid_reference.node
	if _node == null || !is_instance_valid(_node) || !(_node as Node).is_inside_tree():
		return null
	var _scene:Node = get_tree().current_scene
	return _node as PistonGrid if _scene != null && _scene.scene_file_path == HOME_SCENE else null

func _watch(grid:PistonGrid)->void:
	_grid = grid
	_sent_to.clear()
	if _grid == null:
		return
	_grid.changed.connect(_queue_state)
	_grid.write_started.connect(_on_write_started)

## Guests in our home base right now.
func _guests_home()->Array[PlayerState]:
	var _list:Array[PlayerState] = []
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && !_state.ghost && _state.room_scene == HOME_SCENE:
			_list.append(_state)
		elif !_state.is_local:
			_sent_to.erase(_state.peer_id)
	return _list

## A guest reloaded its room: it gets the grid's state again.
func forget(peer:int)->void:
	_sent_to.erase(peer)

func _queue_state()->void:
	if _state_queued:
		return
	_state_queued = true
	_send_state.call_deferred()

func _send_state()->void:
	_state_queued = false
	if _grid == null || !is_instance_valid(_grid):
		return
	var _snapshot:Dictionary = _grid_snapshot()
	for _state:PlayerState in _guests_home():
		_grid_state.rpc_id(_state.peer_id, _snapshot)

func _on_write_started()->void:
	var _snapshot:Dictionary = _grid_snapshot()
	for _state:PlayerState in _guests_home():
		_grid_write.rpc_id(_state.peer_id, _snapshot)

func _grid_snapshot()->Dictionary:
	return {
		"size": _grid.size, "pistons": _grid.piston_bytes(),
		"rows": _grid.row_select, "cols": _grid.col_select,
		"data": _grid.data_value, "gate": int(_grid.gate),
	}

# --- Guest -------------------------------------------------------------------

## Guest: press `node` on the host's side.
func request_use(node:Interactable)->void:
	var _scene:Node = get_tree().current_scene
	if _scene == null || !_scene.is_ancestor_of(node):
		return
	_use_request.rpc_id(1, _scene.scene_file_path, str(_scene.get_path_to(node)))

@rpc("authority", "call_remote", "reliable")
func _grid_state(snapshot:Dictionary)->void:
	var _local:PistonGrid = _guest_grid()
	if _local != null:
		_local.apply_net_state(snapshot, false)

## The host is about to write: its lanes as they are, then the ripple here.
@rpc("authority", "call_remote", "reliable")
func _grid_write(snapshot:Dictionary)->void:
	var _local:PistonGrid = _guest_grid()
	if _local != null:
		_local.apply_net_state(snapshot, true)

func _guest_grid()->PistonGrid:
	if !net().is_guest() || multiplayer.get_remote_sender_id() != 1:
		return null
	var _scene:Node = get_tree().current_scene
	if _scene == null || _scene.scene_file_path != HOME_SCENE:
		return null
	var _node:Object = _grid_reference.node
	return _node as PistonGrid if _node != null && is_instance_valid(_node) else null

# --- Host --------------------------------------------------------------------

func _take_token(peer:int)->bool:
	var _now:int = Time.get_ticks_msec()
	var _bucket:Array = _use_tokens.get(peer, [USE_BURST, _now])
	var _tokens:float = minf(USE_BURST, float(_bucket[0]) + USE_RATE * float(_now - int(_bucket[1])) / 1000.0)
	if _tokens < 1.0:
		_use_tokens[peer] = [_tokens, _now]
		return false
	_use_tokens[peer] = [_tokens - 1.0, _now]
	return true

@rpc("any_peer", "call_remote", "reliable")
func _use_request(room:String, path:String)->void:
	if !net().is_host() || path.length() > MAX_PATH || path.contains(".."):
		return
	var _peer:int = multiplayer.get_remote_sender_id()
	var _state:PlayerState = null
	for _candidate:PlayerState in RunSession.players.all():
		if !_candidate.is_local && _candidate.peer_id == _peer:
			_state = _candidate
	var _scene:Node = get_tree().current_scene
	if _state == null || _state.ghost || _scene == null || room != _scene.scene_file_path || _state.room_scene != room:
		return
	if !_take_token(_peer):
		return
	var _node:Interactable = _scene.get_node_or_null(NodePath(path)) as Interactable
	if _node == null || !_node.is_shared_online() || !_node._can_use():
		return
	_node._use()
	_node.used.emit()
