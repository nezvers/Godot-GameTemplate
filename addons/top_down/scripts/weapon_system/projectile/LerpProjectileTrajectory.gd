class_name LerpProjectileTrajectory
extends Node

@export var projectile:Projectile2D

@export var projectile_mover:ProjectileMover

@export var height_node:Node2D

@export var curve:Curve

@export var shape_cast_transmitter:ShapeCastTransmitter2D

@export var landing_vfx:InstanceResource

@export var landing_sound:SoundResource

func _ready()->void:
	projectile_mover.interpolated_time.connect(_on_interpolation)
	projectile_mover.lerp_finished.connect(_on_lerp_finished.call_deferred)

func _on_interpolation(t:float)->void:
	height_node.position.y = curve.sample(t)

func _on_lerp_finished()->void:
	shape_cast_transmitter.check_transmission()
	var _position:Vector2 = projectile.global_position
	
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _position
	var _inst:Node2D = landing_vfx.instance(_config_callback)
	
	landing_sound.play_managed()
	projectile.prepare_exit()
