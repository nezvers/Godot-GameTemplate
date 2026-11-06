## Stairs from the home base to a new mission. Only one gun may go along:
## with more in hand the stairs refuse and ask to drop the rest.
class_name HomeExitGate
extends Area2D

@export var home_base:HomeBase
@export var weapon_inventory:ItemCollectionResource
## Mission start room
@export_file("*.tscn") var scene_path:String = "res://game/scenes/room_N00.tscn"
@export var hint_label:Label

const TRANSITION_BOOL_PATH := "res://addons/top_down/resources/global_resources/transition_bool_resource.tres"
var _transition_bool:BoolResource = load(TRANSITION_BOOL_PATH)
var _leaving:bool

func _ready()->void:
	disable_mode = DISABLE_MODE_KEEP_ACTIVE
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hint_label.visible = false

func can_leave()->bool:
	return weapon_inventory.list.size() <= 1

func _on_body_entered(_body:Node2D)->void:
	if _leaving || (_transition_bool != null && _transition_bool.value):
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
