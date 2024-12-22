class_name ProjectileImpact
extends Node

@export var projectile:Projectile2D
@export var projectile_mover:ProjectileMover
@export var data_transmitter:DataTransmitter
@export var impact_instance_resource:InstanceResource

func _ready()->void:
	assert(impact_instance_resource != null)
	data_transmitter.success.connect(spawn)
	projectile_mover.bounce_position.connect(spawn)
	projectile_mover.bounces_finished.connect(spawn)

func _config_callback(inst:Node2D)->void:
	inst.global_position = projectile.global_position
	var sprite:Sprite2D = inst.get_node("Sprite2D")
	sprite.rotation = projectile.direction.angle()

func spawn()->void:
	impact_instance_resource.instance(_config_callback)
