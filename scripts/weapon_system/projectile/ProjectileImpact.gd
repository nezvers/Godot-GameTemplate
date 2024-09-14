class_name ProjectileImpact
extends Node

@export var projectile:Projectile2D
@export var damage_source:DamageSource
@export var impact_scene:PackedScene
@export var impact_parent_reference:ReferenceNodeResource

func _ready()->void:
	if impact_scene == null:
		return
	assert(impact_parent_reference != null)
	damage_source.hit.connect(spawn)
	damage_source.hit_solid.connect(spawn)

func spawn()->void:
	# TODO: some vfx might need rotation
	InstanceManager.instance(impact_scene, impact_parent_reference, projectile.global_position)
