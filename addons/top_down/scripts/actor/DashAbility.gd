class_name DashAbility
extends Node

@export var enabled:bool = true
@export var resource_node:ResourceNode
@export var impulse_strength:float = 88.0
@export var cooldown_time:float = 0.8
@export var active_time:float = 0.48

## Can't trigger dashing while is_cooldown
## TODO: maybe needs to be it's own BoolResource
var is_cooldown:bool = false
var dash_bool:BoolResource
var push_resource:PushResource
var input_resource:InputResource

func _ready()->void:
	push_resource = resource_node.get_resource("push")
	assert(push_resource != null)
	dash_bool = resource_node.get_resource("dash")
	assert(dash_bool != null)
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	
	set_enabled(enabled)

func set_enabled(value:bool)->void:
	enabled = value
	if enabled:
		if !input_resource.action_2_pressed.is_connected(dash_pressed):
			input_resource.action_2_pressed.connect(dash_pressed)
	else:
		if input_resource.action_2_pressed.is_connected(dash_pressed):
			input_resource.action_2_pressed.disconnect(dash_pressed)

func dash_pressed()->void:
	if is_cooldown:
		return
	push_resource.add_impulse(input_resource.axis * impulse_strength)
	is_cooldown = true
	# Timer to allow trigger ability again
	var _tween:Tween = create_tween()
	_tween.tween_callback(cooldown_over).set_delay(cooldown_time)
	
	# Dashing state time, allows to go over a hole in ground
	dash_bool.set_value(true)
	var _tween2:Tween = create_tween()
	_tween2.tween_callback(dash_bool.set_value.bind(false)).set_delay(active_time)

func cooldown_over()->void:
	is_cooldown = false
	if input_resource.action_2:
		dash_pressed()
