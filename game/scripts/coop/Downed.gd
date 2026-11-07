## Co-op: the local player goes down at 0 hp instead of dying, while a teammate
## is still up. Added to the local player by NetPlayers while online.
##
## Down: can't move, shoot or be hurt, lies on the floor greyed out. A teammate
## standing next to it for revive_time brings it back with revive_hp_ratio of
## its hp (measured here, from the teammates' positions); clearing the room
## brings everyone back. When the whole party is down the host ends the run
## (NetPlayers._party_wiped -> wipe()), and everyone dies for real.
class_name Downed
extends Node

const ROOM_CLEARED_PATH:String = "res://game/resources/room_cleared_resource.tres"
const GREY:Color = Color(0.55, 0.55, 0.6, 0.85)

var is_down:bool
var progress:float
var _health:HealthResource
var _damage:DamageResource
var _input:InputResource
var _wiped:bool
var _room_cleared:BoolResource
var _label:Label

func body()->Node2D:
	return get_parent() as Node2D

func _ready()->void:
	var _resources:ResourceNode = body().get_node("ResourceNode")
	_health = _resources.get_resource("health")
	_damage = _resources.get_resource("damage")
	_input = _resources.get_resource("input")
	_room_cleared = load(ROOM_CLEARED_PATH)
	_hook()

## The player is carried from room to room (out of the tree and back in).
func _enter_tree()->void:
	if _health != null:
		_hook()

func _hook()->void:
	_health.down_instead = _on_zero_hp
	if !_room_cleared.updated.is_connected(_on_room_cleared):
		_room_cleared.updated.connect(_on_room_cleared)

func _exit_tree()->void:
	if _health != null && _health.down_instead == _on_zero_hp:
		_health.down_instead = Callable()
	if _room_cleared != null && _room_cleared.updated.is_connected(_on_room_cleared):
		_room_cleared.updated.disconnect(_on_room_cleared)

func _on_zero_hp()->bool:
	if is_down:
		return true
	# alone (offline or by ourselves in the session): the usual death
	if _wiped || !Net.is_online() || RunSession.players.count() < 2:
		return false
	go_down()
	return true

func go_down()->void:
	is_down = true
	progress = 0.0
	var _state:PlayerState = RunSession.local_player()
	_state.revive_progress = 0.0
	_set_controls(false)
	_damage.set_can_receive_damage(false)
	_set_look(true)
	_show_label(true)
	RunSession.players.set_downed(RunSession.players.local_slot, true)

func revive(hp_ratio:float)->void:
	if !is_down:
		return
	is_down = false
	progress = 0.0
	RunSession.local_player().revive_progress = 0.0
	_health.hp = maxf(1.0, roundf(_health.max_hp * hp_ratio))
	_health.hp_changed.emit()
	_damage.set_can_receive_damage(true)
	_set_controls(true)
	_set_look(false)
	_show_label(false)
	RunSession.players.set_downed(RunSession.players.local_slot, false)

## The whole party is down: die for real (game over follows as usual).
func wipe()->void:
	_wiped = true
	_show_label(false)
	if is_down:
		is_down = false
		_health.is_dead = true
		_health.dead.emit()
	else:
		_health.insta_kill()

func _on_room_cleared()->void:
	if is_down && _room_cleared.value:
		revive(CoopScaling.revive_hp_ratio())

func _physics_process(delta:float)->void:
	if !is_down:
		return
	if !Net.is_online():
		# the session ended under us: get up rather than lie there forever
		revive(CoopScaling.revive_hp_ratio())
		return
	var _helped:bool = false
	var _radius:float = CoopScaling.revive_radius()
	for _slot:int in Net.players.puppets:
		var _puppet:Node2D = Net.players.puppets[_slot]
		var _state:PlayerState = RunSession.players.get_state(_slot)
		if is_instance_valid(_puppet) && _state != null && !_state.downed && _puppet.global_position.distance_to(body().global_position) <= _radius:
			_helped = true
			break
	progress = progress + delta if _helped else maxf(progress - delta * 0.5, 0.0)
	var _time:float = maxf(CoopScaling.revive_time(), 0.1)
	RunSession.local_player().revive_progress = clampf(progress / _time, 0.0, 1.0)
	if _label != null:
		_label.text = "DOWN - reviving %d%%" % roundi(100.0 * progress / _time) if progress > 0.0 else "DOWN - a teammate can revive you"
	if progress >= _time:
		revive(CoopScaling.revive_hp_ratio())

func _set_controls(enabled:bool)->void:
	var _player_input:Node = body().get_node_or_null("PlayerInput")
	if _player_input != null:
		_player_input.set_enabled(enabled)
	if !enabled:
		_input.set_axis(Vector2.ZERO)
		_input.set_action(false)
		_input.set_action_2(false)

func _set_look(down:bool)->void:
	set_down_look(body(), down)

## Shared with RemotePlayer: lying on the floor, greyed out.
static func set_down_look(player:Node2D, down:bool)->void:
	var _visual:Node2D = player.get_node_or_null("Body")
	if _visual != null:
		_visual.rotation = PI * 0.5 if down else 0.0
		_visual.modulate = GREY if down else Color.WHITE
	var _weapons:Node2D = player.get_node_or_null("WeaponManager")
	if _weapons != null:
		_weapons.visible = !down

func _show_label(visible_now:bool)->void:
	if !visible_now:
		if _label != null:
			_label.get_parent().queue_free()
			_label = null
		return
	if _label != null:
		return
	var _layer:CanvasLayer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	_label = Label.new()
	_label.text = "DOWN - a teammate can revive you"
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_top = -48
	_label.offset_bottom = -36
	_label.offset_left = -120
	_label.offset_right = 120
	_layer.add_child(_label)
