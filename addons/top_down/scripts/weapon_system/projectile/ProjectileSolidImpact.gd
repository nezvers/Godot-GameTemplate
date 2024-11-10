## Not sure how to call the class without creating problems in future
class_name ProjectileSolidImpact
extends Node

signal hit

@export var projectile:Projectile2D
@export var area_transmitter:AreaTransmitter2D

## Will check for body collisions with these flags
@export_flags_2d_physics var destroy_collision_mask:int = 1

func _ready()->void:
	if destroy_collision_mask == 0:
		return
	area_transmitter.collision_mask = Bitwise.append_flags(area_transmitter.collision_mask, destroy_collision_mask)
	area_transmitter.body_entered.connect(on_body_entered)

func on_body_entered(body:Node2D)->void:
	if body is TileMapLayer || body is TileMap:
		hit.emit()
		on_hit()
		return
	if (body as PhysicsBody2D).collision_layer & destroy_collision_mask != 0:
		hit.emit()
		on_hit()
		return

func on_hit()->void:
	projectile.prepare_exit()
