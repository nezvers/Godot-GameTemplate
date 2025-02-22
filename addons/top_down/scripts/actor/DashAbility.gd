class_name DashAbility
extends Node

@export var enabled:bool = true

@export var resource_node:ResourceNode

@export var impulse_strength:float = 88.0

@export var cooldown_time:float = 0.8

@export var active_time:float = 0.48

@export var after_image_instance:InstanceResource

@export var sprite:Sprite2D

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
	
	request_ready()

func set_enabled(value:bool)->void:
	enabled = value
	if enabled:
		if !input_resource.action_2_pressed.is_connected(_dash_pressed):
			input_resource.action_2_pressed.connect(_dash_pressed)
	else:
		if input_resource.action_2_pressed.is_connected(_dash_pressed):
			input_resource.action_2_pressed.disconnect(_dash_pressed)

func _dash_pressed()->void:
	if is_cooldown:
		return
	if input_resource.axis.length_squared() < 0.1:
		return
	
	push_resource.add_impulse(input_resource.axis * impulse_strength)
	is_cooldown = true
	# Timer to allow trigger ability again
	var _tween:Tween = create_tween()
	_tween.tween_callback(_cooldown_over).set_delay(cooldown_time)
	
	# Dashing state time, allows to go over a hole in ground
	dash_bool.set_value(true)
	var _tween2:Tween = create_tween()
	_tween2.tween_callback(dash_bool.set_value.bind(false)).set_delay(active_time)
	
	var _tween3:Tween = create_tween().set_loops(3)
	_tween3.tween_callback(_spawn_after_image).set_delay(0.1)
	_spawn_after_image()

func _cooldown_over()->void:
	is_cooldown = false
	if input_resource.action_2:
		_dash_pressed()

func _spawn_after_image()->void:
	var _config_callback:Callable = func (inst:AfterImageVFX)->void:
		inst.setup(sprite.texture, sprite.hframes, sprite.vframes, sprite.frame, sprite.centered, sprite.offset, sprite.position, owner.global_position)
	
	after_image_instance.instance(_config_callback)
