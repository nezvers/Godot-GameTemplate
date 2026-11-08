## Every player in the session, by slot (0..MAX_PLAYERS-1). Slot 0 is the host
## or the single player. The local player's state also backs player_reference
## and the HUD; code that needs "every player" (targeting, game over, revives,
## the party HUD) asks here instead.
class_name PlayerRegistry
extends RefCounted

signal player_added(state:PlayerState)
signal player_removed(state:PlayerState)
signal player_downed(state:PlayerState)
signal all_downed

const MAX_PLAYERS:int = 8

## slot -> PlayerState
var states:Dictionary = {}
## slot -> player Node2D while spawned
var nodes:Dictionary = {}
var local_slot:int = 0

func local()->PlayerState:
	return states.get(local_slot)

func get_state(slot:int)->PlayerState:
	return states.get(slot)

func all()->Array[PlayerState]:
	var _list:Array[PlayerState] = []
	var _slots:Array = states.keys()
	_slots.sort()
	for _slot:int in _slots:
		_list.append(states[_slot])
	return _list

func count()->int:
	return states.size()

## Players in the fight (no ghosts, players waiting at a door or the server's
## hidden player).
func active()->Array[PlayerState]:
	var _list:Array[PlayerState] = []
	for _state:PlayerState in all():
		if _state.is_active():
			_list.append(_state)
	return _list

func count_active()->int:
	return active().size()

func free_slot()->int:
	for _slot:int in MAX_PLAYERS:
		if !states.has(_slot):
			return _slot
	return -1

func add(state:PlayerState)->void:
	states[state.slot] = state
	player_added.emit(state)

func remove(slot:int)->void:
	var _state:PlayerState = states.get(slot)
	if _state == null:
		return
	states.erase(slot)
	nodes.erase(slot)
	player_removed.emit(_state)

func find_profile(profile_id:String)->PlayerState:
	for _state:PlayerState in states.values():
		if _state.profile_id == profile_id:
			return _state
	return null

func set_node(slot:int, node:Node2D)->void:
	nodes[slot] = node

func set_downed(slot:int, value:bool)->void:
	var _state:PlayerState = states.get(slot)
	if _state == null || _state.downed == value:
		return
	_state.downed = value
	if !value:
		return
	player_downed.emit(_state)
	check_all_downed()

## Nobody in the fight is left standing (a ghost leaving can cause it too).
func check_all_downed()->void:
	var _active:Array[PlayerState] = active()
	if _active.is_empty():
		return
	for _other:PlayerState in _active:
		if !_other.downed:
			return
	all_downed.emit()
