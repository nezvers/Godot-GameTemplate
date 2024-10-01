class_name HitLimit
extends Node

@export var projectile:Projectile2D
@export var damage_transmitter:DamageTransmitter
## Projectile is removed when reaching 0
## Starting with negative has infinite count
@export var hit_limit:int = 1

func _ready()->void:
	if hit_limit < 1:
		return
	damage_transmitter.hit.connect(on_hit)

func on_hit()->void:
	if hit_limit < 1:
		return
	hit_limit -= 1
	if hit_limit != 0:
		return
	
	projectile.prepare_exit()
