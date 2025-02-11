class_name BigJellyJumpDamage
extends Node

@export var jump_move:JumpMove

@export var chase_player:BigJellyChase

@export var area_receiver:AreaReceiver2D

@export var damage_transmitter:ShapeCastTransmitter2D

@export var push_transmitter:ShapeCastTransmitter2D

@export var push_channel_transmitter:DataChannelTransmitter

@export var axis_multiplication:Vector2Resource

@export var kickback_radius:float = 40.0

@export var kickback_curve:Curve

@export var kickback_max:float

@export var kickback_min:float

var receiver_collision_layer:int

var axis_compensation:Vector2

func _ready() -> void:
	receiver_collision_layer = area_receiver.collision_layer
	axis_compensation = Vector2.ONE / axis_multiplication.value
	push_channel_transmitter.update_requested.connect(_update_push)
	jump_move.jump_started.connect(_on_jump)
	jump_move.jump_finished.connect(_on_land)

func _on_jump()->void:
	area_receiver.collision_layer = 0

func _on_land()->void:
	area_receiver.collision_layer = receiver_collision_layer
	damage_transmitter.check_transmission()
	push_transmitter.check_transmission()

func _update_push(damage_data:DamageDataResource, receiver:AreaReceiver2D)->void:
	var _distance:Vector2 = receiver.global_position - push_transmitter.global_position
	var _distance_length:float = (_distance * axis_compensation).length()
	var _interpolation:float = min(_distance_length / kickback_radius, 1.0)
	var _t:float = kickback_curve.sample(_interpolation)
	damage_data.kickback_strength = lerp(kickback_max, kickback_min, _t)
	
	if _distance_length > 2.0:
		damage_data.direction = _distance.normalized()
	else:
		## too close to center, push in jump direction
		damage_data.direction = chase_player.direction.normalized()
