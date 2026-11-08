## The dedicated server's own player (server_player.tscn, an extended player
## scene with everything a person would see or use switched off). It exists so
## the rooms keep working as they do around a host's player: the spawner carries
## it through doors, player_reference points at it, and nothing else changes.
##
## Here it only follows the party leader (the active guest with the lowest slot
## in this room) and never dies, unless the whole party is down (wipe()).
class_name ServerAnchor
extends Node

var _health:HealthResource
var _damage:DamageResource
var _wiped:bool

func body()->Node2D:
	return get_parent() as Node2D

func _ready()->void:
	var _resources:ResourceNode = body().get_node("ResourceNode")
	_health = _resources.get_resource("health")
	_damage = _resources.get_resource("damage")
	RunSession.local_player().hidden = true
	_hook()
	# after the guests' puppets have moved this frame
	process_physics_priority = 20

## Carried from room to room: _ready doesn't run again.
func _enter_tree()->void:
	if _health != null:
		_hook()

func _hook()->void:
	_health.down_instead = _never_down
	if _damage != null:
		_damage.immune = true

func _exit_tree()->void:
	if _health != null && _health.down_instead == _never_down:
		_health.down_instead = Callable()

func _never_down()->bool:
	return !_wiped

func _physics_process(_delta:float)->void:
	var _leader:Node2D = leader()
	if _leader != null:
		body().global_position = _leader.global_position

## The active guest with the lowest slot whose copy is in this room.
static func leader()->Node2D:
	var _slots:Array = Net.players.puppets.keys()
	_slots.sort()
	for _slot:int in _slots:
		var _state:PlayerState = RunSession.players.get_state(_slot)
		var _puppet:Node2D = Net.players.puppets[_slot]
		if _state != null && _state.is_active() && is_instance_valid(_puppet) && _puppet.is_inside_tree():
			return _puppet
	return null

## The whole party is down: the run ends here as it does for a host.
func wipe()->void:
	_wiped = true
	_health.insta_kill()
