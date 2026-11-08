## Co-op: the reviving side of Downed. Child of NetPlayers (/root/Net/Players).
## Walking up to a downed teammate shows "E to REVIVE" above them; holding the
## interact key there sets PlayerState.reviving, sent with our updates. The downed
## player's machine counts the revive time while a teammate in range holds it.
class_name ReviveAssist
extends Node

const ACTION_PATH:String = "res://addons/top_down/resources/global_resources/action_resource.tres"
const LABEL_NAME:String = "ReviveLabel"
const COLOR:Color = Color(1.0, 0.9, 0.45)

## Tests: hold the key without an input map.
static var force_hold:bool

var target:Node2D
var _action:ActionResource
var _label:Label

func _ready()->void:
	_action = load(ACTION_PATH)
	process_physics_priority = -2

func _exit_tree()->void:
	_set_target(null)

func players()->NetPlayers:
	return get_parent() as NetPlayers

func _physics_process(_delta:float)->void:
	var _local:PlayerState = RunSession.local_player()
	var _next:Node2D = _find_target(_local) if Net.is_online() else null
	_set_target(_next)
	var _holding:bool = _next != null && held()
	if _local != null:
		_local.reviving = _holding
	if _label != null:
		var _state:PlayerState = _state_of(_next)
		var _progress:float = _state.revive_progress if _state != null else 0.0
		_label.text = "REVIVING %d%%" % roundi(100.0 * _progress) if _holding else "%s to REVIVE" % key_name()

func held()->bool:
	if force_hold:
		return true
	var _name:StringName = _action.interact_action if _action != null else &""
	return _name != &"" && InputMap.has_action(_name) && Input.is_action_pressed(_name)

## The key bound to interact, as the player sees it.
func key_name()->String:
	if _action != null && _action.interact_action != &"" && InputMap.has_action(_action.interact_action):
		for _event:InputEvent in InputMap.action_get_events(_action.interact_action):
			if _event is InputEventKey:
				var _key:InputEventKey = _event
				var _code:Key = _key.physical_keycode if _key.keycode == KEY_NONE else _key.keycode
				return OS.get_keycode_string(_code)
	return "E"

## The closest downed teammate within revive range, while we stand.
func _find_target(local:PlayerState)->Node2D:
	var _body:Node2D = players().local_body()
	if _body == null || local == null || local.downed || !local.is_active():
		return null
	var _radius:float = CoopScaling.revive_radius()
	var _best:Node2D = null
	var _best_distance:float = INF
	for _slot:int in players().puppets:
		var _puppet:Node2D = players().puppets[_slot]
		var _state:PlayerState = RunSession.players.get_state(_slot)
		if !is_instance_valid(_puppet) || !_puppet.is_inside_tree() || _state == null || !_state.downed:
			continue
		var _distance:float = _puppet.global_position.distance_to(_body.global_position)
		if _distance <= _radius && _distance < _best_distance:
			_best = _puppet
			_best_distance = _distance
	return _best

func _state_of(puppet:Node2D)->PlayerState:
	if puppet == null:
		return null
	for _slot:int in players().puppets:
		if players().puppets[_slot] == puppet:
			return RunSession.players.get_state(_slot)
	return null

func _set_target(next:Node2D)->void:
	if next == target && (next == null || _label != null && is_instance_valid(_label)):
		return
	if _label != null && is_instance_valid(_label):
		_label.queue_free()
	_label = null
	target = next if next != null && is_instance_valid(next) else null
	if target == null:
		return
	_label = Label.new()
	_label.name = LABEL_NAME
	_label.z_index = 20
	_label.offset_left = -60
	_label.offset_right = 60
	_label.offset_top = -30
	_label.offset_bottom = -21
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 6)
	_label.add_theme_color_override("font_color", COLOR)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.text = "%s to REVIVE" % key_name()
	target.add_child(_label)
