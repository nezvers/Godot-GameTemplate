## A co-op teammate drawn on this machine: the regular player scene, driven by
## network updates instead of the keyboard (NetPlayers feeds it).
##
## Built from player.tscn with everything that belongs to the *local* player
## taken out before it enters the tree: input, camera, the player reference,
## screen juice, the run reset hooks and meta stats. Health and weapons point at
## the teammate's own PlayerState copies, so the weapon in hand is drawn and
## aimed like the local one. It picks nothing up and ignores traps (only the
## damage receiver is kept): a hit on it is measured here and, on the host, sent
## to the teammate's machine, which applies it (NetEntities). Its body stays on
## the player layer so enemies chase it and the host's doors notice it.
class_name RemotePlayer
extends Node

const PLAYER_SCENE:String = "res://addons/top_down/scenes/actors/player.tscn"
## Nodes that only make sense for the player at this keyboard.
const LOCAL_ONLY:PackedStringArray = [
	"PlayerInput", "DebugInput", "ReferencePlayer", "PlayerJuice", "ResetHealth",
	"CameraPositionSetter", "MetaStats",
]
## Further than this from the reported spot: jump there instead of catching up.
const SNAP_DISTANCE:float = 48.0
## Share of the remaining distance closed each physics frame.
const CATCH_UP:float = 0.25

var state:PlayerState
var target_position:Vector2
var axis:Vector2
var aim:Vector2 = Vector2.RIGHT

var _input:InputResource
var _damage:DamageResource
var _has_target:bool

## The puppet for `state`, at `at`. Add it under the room's y-sort node.
static func create(for_state:PlayerState, at:Vector2)->Node2D:
	var _player:Node2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.name = "Player_%d" % for_state.slot
	_player.global_position = at
	for _name:String in LOCAL_ONLY:
		var _node:Node = _player.get_node_or_null(_name)
		if _node != null:
			_player.remove_child(_node)
			_node.free()
	var _receiver:Area2D = _player.get_node_or_null("AreaReceiver2D")
	if _receiver != null:
		for _child:Node in _receiver.get_children():
			if _child is DataChannelReceiver && _child.name != "DamageDataReceiver":
				_receiver.remove_child(_child)
				_child.free()
	_use_state_resources(_player.get_node("ResourceNode"), for_state)
	PlayerSkin.apply(_player, for_state.slot)
	var _driver:RemotePlayer = RemotePlayer.new()
	_driver.name = "RemotePlayer"
	_driver.state = for_state
	_driver.target_position = at
	_player.add_child(_driver)
	_player.add_to_group(&"remote_player")
	return _player

## The scene's items are shared sub-resources: replace them, never edit them.
static func _use_state_resources(resource_node:ResourceNode, for_state:PlayerState)->void:
	var _own:Dictionary = {"health": for_state.health, "weapons": for_state.inventory}
	var _list:Array[ResourceNodeItem] = []
	for _item:ResourceNodeItem in resource_node.list:
		if _own.has(_item.resource_name):
			var _replacement:ResourceNodeItem = ResourceNodeItem.new()
			_replacement.resource_name = _item.resource_name
			_replacement.resource = _own[_item.resource_name]
			_replacement.make_unique = false
			_list.append(_replacement)
		else:
			_list.append(_item)
	resource_node.list = _list

func _ready()->void:
	var _resources:ResourceNode = owner_node().get_node("ResourceNode")
	_input = _resources.get_resource("input")
	_damage = _resources.get_resource("damage")
	if _damage != null:
		_damage.forward_hit = _on_hit
	# after the mover has moved the body this frame
	process_physics_priority = 10

func owner_node()->Node2D:
	return get_parent() as Node2D

## Only the host's hits count: enemies and their shots are real there.
func _on_hit(data:DamageDataResource)->void:
	if Net.is_host():
		Net.entities.send_hurt(state, data)

## A network update for this teammate.
func push(at:Vector2, move_axis:Vector2, aim_direction:Vector2)->void:
	target_position = at
	axis = move_axis
	if aim_direction.length_squared() > 0.0001:
		aim = aim_direction
	_has_target = true

var _shown_down:bool
var _shown_faint:bool
## Body / receiver layers to give back when it stops being faint.
var _layers:Vector2i = Vector2i(-1, -1)

## How see-through a teammate is drawn: a ghost from its own home base, or one
## waiting at the door for a fight to end.
const GHOST_ALPHA:float = 0.35
const WAITING_ALPHA:float = 0.5

## Untouchable teammates (away at home, waiting at a door): enemies don't find
## them (no body layer) and nothing hits them (receiver off).
func _set_untouchable(untouchable:bool)->void:
	_shown_faint = untouchable
	var _body:CollisionObject2D = owner_node() as CollisionObject2D
	var _receiver:Area2D = owner_node().get_node_or_null("AreaReceiver2D")
	if untouchable:
		if _layers.x < 0 && _body != null:
			_layers = Vector2i(_body.collision_layer, _receiver.collision_layer if _receiver != null else 0)
		if _body != null:
			_body.collision_layer = 0
		if _receiver != null:
			_receiver.collision_layer = 0
			_receiver.set_deferred("monitoring", false)
	elif _layers.x >= 0:
		if _body != null:
			_body.collision_layer = _layers.x
		if _receiver != null:
			_receiver.collision_layer = _layers.y
			_receiver.set_deferred("monitoring", true)
		_layers = Vector2i(-1, -1)

func _faint_now()->bool:
	return state.ghost || state.waiting

## Downed copies too: enemies walk past them instead of shoving them around.
func _untouchable_now()->bool:
	return _faint_now() || state.downed

## How see-through this teammate is drawn right now (1 = solid).
func _alpha_now()->float:
	if state.ghost:
		return GHOST_ALPHA
	if state.waiting:
		return WAITING_ALPHA
	return GuestTier.alpha(state)

func _physics_process(_delta:float)->void:
	if _input == null:
		return
	if state.downed != _shown_down:
		_shown_down = state.downed
		Downed.set_down_look(owner_node(), _shown_down)
	# a downed or waiting teammate's copy takes no hits here either
	if _damage != null:
		_damage.immune = state.downed || state.waiting || state.ghost
	if _untouchable_now() != _shown_faint:
		_set_untouchable(_untouchable_now())
	var _visual:Node2D = owner_node().get_node_or_null("Body")
	if _visual != null && !state.downed:
		_visual.modulate.a = _alpha_now()
	_input.set_axis(Vector2.ZERO if state.downed else axis)
	_input.set_aim_direction(aim)
	if !_has_target:
		return
	var _body:Node2D = owner_node()
	var _gap:Vector2 = target_position - _body.global_position
	if _gap.length() > SNAP_DISTANCE:
		_body.global_position = target_position
	else:
		_body.global_position += _gap * CATCH_UP
