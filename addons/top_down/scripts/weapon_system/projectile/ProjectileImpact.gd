class_name ProjectileImpact
extends Node

@export var projectile:Projectile2D
@export var data_transmitter:DataTransmitter
@export var solid_impact:ProjectileSolidImpact
@export var impact_scene:PackedScene
@export var impact_parent_reference:ReferenceNodeResource

func _ready()->void:
	if impact_scene == null:
		return
	assert(impact_parent_reference != null)
	data_transmitter.success.connect(spawn)
	solid_impact.hit.connect(spawn)

func spawn()->void:
	# TODO: some vfx might need rotation
	InstanceManager.instance_2d(impact_scene, impact_parent_reference, projectile.global_position)
