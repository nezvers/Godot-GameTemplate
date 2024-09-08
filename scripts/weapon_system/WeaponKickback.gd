class_name WeaponKickback
extends Node

@export var weapon:Weapon
@export var kickback_strength:float

func _ready()->void:
	weapon.projectile_created.connect(apply_kickback)

func apply_kickback()->void:
	var direction:Vector2 = weapon.mover.input_resource.aim_direction.normalized()
	weapon.mover.add_impulse(kickback_strength * -direction)
