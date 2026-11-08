## Stairs from the home base to a new mission. Only one gun may go along:
## with more in hand the stairs refuse and ask to drop the rest.
## The New Game+ stairs (requires_ng_plus) only show once New Game+ is unlocked:
## our own campaign, or as a co-op guest the host's (Net.host_ng_plus).
class_name HomeExitGate
extends Area2D

@export var home_base:HomeBase
@export var weapon_inventory:ItemCollectionResource
## Mission start room
@export_file("*.tscn") var scene_path:String = "res://game/scenes/room_N00.tscn"
@export var hint_label:Label
## Hidden and shut until New Game+ is unlocked.
@export var requires_ng_plus:bool
@export var campaign_resource:CampaignResource

const TRANSITION_BOOL_PATH := "res://addons/top_down/resources/global_resources/transition_bool_resource.tres"
var _transition_bool:BoolResource = load(TRANSITION_BOOL_PATH)
var _leaving:bool

func _ready()->void:
	disable_mode = DISABLE_MODE_KEEP_ACTIVE
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hint_label.visible = false
	if requires_ng_plus:
		assert(campaign_resource != null)
		if !Net.is_guest():
			campaign_resource.load_resource()
		campaign_resource.updated.connect(_refresh_lock)
		Net.roster_changed.connect(_refresh_lock)
		Net.state_changed.connect(_refresh_lock)
		_refresh_lock()

func _exit_tree()->void:
	if !requires_ng_plus:
		return
	for _signal:Signal in [campaign_resource.updated, Net.roster_changed, Net.state_changed]:
		if _signal.is_connected(_refresh_lock):
			_signal.disconnect(_refresh_lock)

## The stairs are there (always, unless they need New Game+).
func is_unlocked()->bool:
	if !requires_ng_plus:
		return true
	return Net.host_ng_plus if Net.is_guest() else campaign_resource.ng_plus_unlocked

func _refresh_lock()->void:
	var _open:bool = is_unlocked()
	visible = _open
	set_deferred("monitoring", _open)
	if !_open:
		hint_label.visible = false

func can_leave()->bool:
	return weapon_inventory.list.size() <= 1

func _on_body_entered(_body:Node2D)->void:
	if _leaving || (_transition_bool != null && _transition_bool.value):
		return
	# co-op guests leave when the host does (NetPlayers)
	if Net.is_guest():
		hint_label.text = "The host leads the way"
		hint_label.visible = true
		return
	if !can_leave():
		hint_label.text = "Carry only 1 gun - drop the rest [%s]" % _drop_key()
		hint_label.visible = true
		return
	_leaving = true
	home_base.depart()
	Transition.change_scene(scene_path)

func _on_body_exited(_body:Node2D)->void:
	hint_label.visible = false

func _drop_key()->String:
	var _event:InputEvent = load("res://addons/top_down/resources/global_resources/action_resource.tres").drop_kb
	if _event is InputEventKey:
		return _event.as_text_physical_keycode()
	return "drop"
