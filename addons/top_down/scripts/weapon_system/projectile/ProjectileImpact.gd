class_name ProjectileImpact
extends Node

@export var projectile:Projectile2D
@export var data_transmitter:DataTransmitter
@export var solid_impact:ProjectileSolidImpact
@export var impact_instance_resource:InstanceResource

func _ready()->void:
	assert(impact_instance_resource != null)
	data_transmitter.success.connect(spawn, CONNECT_ONE_SHOT)
	solid_impact.hit.connect(spawn, CONNECT_ONE_SHOT)

func _config_callback(inst:Node2D)->void:
	inst.global_position = projectile.global_position
	var sprite:Sprite2D = inst.get_node("Sprite2D")
	sprite.rotation = projectile.direction.angle()

func spawn()->void:
	impact_instance_resource.instance(_config_callback)
