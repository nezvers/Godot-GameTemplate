## Co-op guest back from its own home base (the rejoin portal) into a room where
## a fight may be on: it waits by the door it came through until the walls drop.
## Added to the local player by NetPlayers on arrival.
##
## While waiting: faint, can't be hurt or targeted (the host sees it as waiting
## and makes its copy untouchable), can't shoot, and stays within LEASH of the
## door. Stepping back into the door asks whether to go home again
## (GuestLeaveMenu). Once no section in the room is fighting it lets go.
class_name WaitingAtDoor
extends Node

const LEASH:float = 40.0
## The host's fight state reaches us just after we arrive: don't let go before
## it has (NetEntities.synced_room), nor before SETTLE_TIME; MAX_SETTLE caps it.
const SETTLE_TIME:float = 0.5
const MAX_SETTLE:float = 10.0
const ALPHA:float = 0.5
const TRANSITION_PATH:String = "res://addons/top_down/resources/global_resources/scene_transition_resource.tres"

## Released (or the menu sent us home) this frame.
signal finished

var anchor:Vector2
var door:SceneEntry
var _settle_left:float = SETTLE_TIME
var _waited:float
var _damage:DamageResource
var _label:Label
var _left_door:bool
var _menu:GuestLeaveMenu

func body()->Node2D:
	return get_parent() as Node2D

func _ready()->void:
	anchor = body().global_position
	var _transition:SceneTransitionResource = load(TRANSITION_PATH)
	door = _transition.entry_match as SceneEntry if is_instance_valid(_transition.entry_match) else null
	if door != null:
		anchor = door.global_position.lerp(anchor, 0.5)
		door.body_entered.connect(_on_door_entered)
		door.body_exited.connect(_on_door_exited)
	var _resources:ResourceNode = body().get_node("ResourceNode")
	_damage = _resources.get_resource("damage")
	_set_waiting(true)
	# after the mover: the leash has the last word on the position
	process_physics_priority = 20

func _exit_tree()->void:
	if door != null && is_instance_valid(door):
		if door.body_entered.is_connected(_on_door_entered):
			door.body_entered.disconnect(_on_door_entered)
		if door.body_exited.is_connected(_on_door_exited):
			door.body_exited.disconnect(_on_door_exited)

func _set_waiting(value:bool)->void:
	RunSession.local_player().waiting = value
	if _damage != null:
		_damage.immune = value
	var _weapons:Node2D = body().get_node_or_null("WeaponManager")
	if _weapons != null:
		_weapons.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
		_weapons.visible = !value
	var _visual:Node2D = body().get_node_or_null("Body")
	if _visual != null:
		_visual.modulate.a = ALPHA if value else 1.0
	_show_label(value)

func _physics_process(delta:float)->void:
	if !Net.is_guest():
		release()
		return
	var _offset:Vector2 = body().global_position - anchor
	if _offset.length() > LEASH:
		body().global_position = anchor + _offset.limit_length(LEASH)
	_settle_left -= delta
	_waited += delta
	var _synced:bool = Net.entities.synced_room == get_tree().current_scene.scene_file_path || _waited >= MAX_SETTLE
	if _settle_left <= 0.0 && _synced && !fight_on():
		release()

## Any section in this room has its walls up.
func fight_on()->bool:
	for _section:ArenaSection in NetEntities._sections(get_tree().current_scene):
		if _section.fight_active && !_section.is_cleared:
			return true
	return false

## Walls down (or the session ended): a full member of the party again.
func release()->void:
	if is_queued_for_deletion():
		return
	_set_waiting(false)
	_close_menu()
	finished.emit()
	queue_free()

func _on_door_exited(other:Node2D)->void:
	if other == body():
		_left_door = true

## Back into the stairs we came through: go home again, or keep waiting.
func _on_door_entered(other:Node2D)->void:
	if other != body() || !_left_door || _menu != null:
		return
	_left_door = false
	_menu = GuestLeaveMenu.open(self, GuestLeaveMenu.Context.DOOR)
	_menu.stay_chosen.connect(_close_menu)

func _close_menu()->void:
	if _menu != null && is_instance_valid(_menu):
		_menu.close()
	_menu = null

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
	_label.text = "Fight in progress - you'll join when the walls drop"
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_top = -48
	_label.offset_bottom = -36
	_label.offset_left = -140
	_label.offset_right = 140
	_layer.add_child(_label)
