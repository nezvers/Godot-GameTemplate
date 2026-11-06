## Base for puddle effects: active while a BoolResource keeps getting set
## (TrapTransmission with repeat_while_inside pulses it every physics frame)
## and for linger_time after the last pulse.
## Creates its BoolResource when the actor's ResourceNode lacks one, so every
## actor inheriting actor.tscn reacts without listing it.
class_name PulseEffect
extends Node

@export var resource_node:ResourceNode

## Name of the BoolResource puddles set, e.g. "slippery"
@export var effect_name:StringName

## Seconds the effect stays after the last pulse (after leaving the puddle)
@export var linger_time:float = 0.1

var effect_bool:BoolResource
var remaining_time:float

func _ready()->void:
	effect_bool = ensure_bool(resource_node, effect_name)
	if effect_bool == null || !_setup():
		set_physics_process(false)
		return
	effect_bool.changed_true.connect(_on_pulse)
	set_physics_process(true)

	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(_on_tree_exiting, CONNECT_ONE_SHOT)

## Returns the actor's BoolResource `name`, adding a unique one when missing.
## Written into the dictionary only: ResourceNode.list may be shared between instances.
static func ensure_bool(node:ResourceNode, name:StringName)->BoolResource:
	if node == null || name.is_empty():
		return null
	var _existing:SaveableResource = node.get_resource(name)
	if _existing != null:
		return _existing as BoolResource
	var _item:ResourceNodeItem = ResourceNodeItem.new()
	_item.resource_name = name
	_item.resource = BoolResource.new()
	_item.value = _item.resource
	node.dictionary[name] = _item
	return _item.value

## Override: read resources, return false to disable the effect
func _setup()->bool:
	return true

## Override: effect starts
func _start()->void:
	pass

## Override: effect ends
func _stop()->void:
	pass

func _on_pulse()->void:
	# reset so next pulse triggers changed_true again
	effect_bool.set_value(false)
	if remaining_time <= 0.0:
		_start()
	remaining_time = linger_time

func is_active()->bool:
	return remaining_time > 0.0

func _physics_process(delta:float)->void:
	if remaining_time <= 0.0:
		return
	remaining_time -= delta
	if remaining_time <= 0.0:
		_stop()

func _on_tree_exiting()->void:
	if remaining_time > 0.0:
		remaining_time = 0.0
		_stop()
	effect_bool.changed_true.disconnect(_on_pulse)
