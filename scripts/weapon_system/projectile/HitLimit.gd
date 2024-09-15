class_name HitLimit
extends Node

@export var projectile:Projectile2D
@export var damage_source:DamageSource
## Projectile is removed when reaching 0
## Starting with negative has infinite count
@export var hit_limit:int = 1

func _ready()->void:
	if hit_limit < 1:
		return
	damage_source.hit.connect(on_hit)
	damage_source.hit_solid.connect(on_hit_solid)

func on_hit_solid()->void:
	projectile.prepare_exit()

func on_hit()->void:
	if hit_limit < 1:
		return
	hit_limit -= 1
	if hit_limit != 0:
		return
	
	projectile.prepare_exit()
