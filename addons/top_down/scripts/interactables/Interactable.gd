## Base for room contraptions the player uses with the interact action.
## Shows a prompt while the player stands in `area`; when several overlap only
## the nearest one shows its prompt and reacts.
class_name Interactable
extends Node2D

signal used

const GROUP:StringName = &"interactable_in_range"
## Every contraption in the room, for listeners such as the zen announcer.
const ALL_GROUP:StringName = &"interactable"

@export var area:Area2D
@export_flags_2d_physics var collision_mask:int = 2
@export var prompt_label:Label
## Shaken when a use is denied.
@export var shake_node:Node2D
@export var action_resource:ActionResource
@export var player_reference:ReferenceNodeResource
@export var sound_use:SoundResource
@export var sound_denied:SoundResource
## Stops a single press from triggering twice.
@export var use_cooldown:float = 0.3

## Set while a use plays out (e.g. slot reels spinning); presses are ignored.
var busy:bool

var _in_range:bool
var _cooldown_left:float
var _shake_tween:Tween

func _ready()->void:
	add_to_group(ALL_GROUP)
	area.collision_layer = 0
	area.collision_mask = collision_mask
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	prompt_label.visible = false

func _exit_tree()->void:
	remove_from_group(GROUP)

func _on_body_entered(_body:Node2D)->void:
	_in_range = true
	add_to_group(GROUP)

func _on_body_exited(_body:Node2D)->void:
	_in_range = false
	remove_from_group(GROUP)
	prompt_label.visible = false

func _process(delta:float)->void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var _show:bool = _in_range && is_nearest()
	prompt_label.visible = _show
	if _show:
		prompt_label.text = "[%s] %s" % [_key_text(), _prompt_text()]

func _unhandled_input(event:InputEvent)->void:
	if !_in_range || !event.is_action_pressed(action_resource.interact_action):
		return
	if !is_nearest():
		return
	get_viewport().set_input_as_handled()
	try_use()

## Runs one use, or the denied feedback when it isn't possible right now.
func try_use()->void:
	if busy || _cooldown_left > 0.0:
		return
	_cooldown_left = use_cooldown
	if !_can_use():
		deny()
		return
	if sound_use != null:
		sound_use.play_managed()
	_use()
	used.emit()

func deny()->void:
	if sound_denied != null:
		sound_denied.play_managed()
	if shake_node == null:
		return
	if _shake_tween != null:
		_shake_tween.kill()
	shake_node.position.x = 0.0
	_shake_tween = create_tween()
	for _offset:float in [2.0, -2.0, 1.0, -1.0, 0.0]:
		_shake_tween.tween_property(shake_node, "position:x", _offset, 0.04)

func is_nearest()->bool:
	var _player:Node2D = player_reference.node
	if _player == null:
		return false
	var _best:Node2D = null
	var _best_distance:float = INF
	for _node:Node in get_tree().get_nodes_in_group(GROUP):
		var _distance:float = (_node as Node2D).global_position.distance_squared_to(_player.global_position)
		if _distance < _best_distance:
			_best_distance = _distance
			_best = _node
	return _best == self

func _key_text()->String:
	var _event:InputEvent = action_resource.interact_gp if !action_resource.mouse_aim && action_resource.interact_gp != null else action_resource.interact_kb
	if _event is InputEventKey:
		var _keycode:Key = _event.keycode
		if _keycode == KEY_NONE:
			_keycode = DisplayServer.keyboard_get_keycode_from_physical(_event.physical_keycode)
		return OS.get_keycode_string(_keycode)
	if _event is InputEventJoypadButton:
		return ["A", "B", "X", "Y"][_event.button_index] if _event.button_index < 4 else "Btn %d" % _event.button_index
	return "?"

# --- overridden by contraptions ------------------------------------------------

func _can_use()->bool:
	return true

func _use()->void:
	pass

func _prompt_text()->String:
	return ""
