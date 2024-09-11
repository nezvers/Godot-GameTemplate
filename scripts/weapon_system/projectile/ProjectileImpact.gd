class_name ProjectileImpact
extends Node

@export var projectile:Projectile2D
@export var damage_source:DamageSource
@export var impact_scene:PackedScene

func _ready()->void:
	if impact_scene == null:
		return
	damage_source.hit.connect(spawn)

func spawn()->void:
	var inst:Node2D = impact_scene.instantiate()
	var parent:Node2D = projectile.get_parent()
	parent.add_child(inst)
	inst.global_position = projectile.global_position
	# TODO: some vfx might need rotation
