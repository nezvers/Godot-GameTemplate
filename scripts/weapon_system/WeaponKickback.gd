class_name WeaponKickback
extends Node

@export var weapon_trigger:WeaponTrigger
@export var weapon:Weapon
@export var kickback_strength:float

func _ready()->void:
	weapon_trigger.shoot_event.connect(apply_kickback)

func apply_kickback()->void:
	var direction:Vector2 = weapon_trigger.get_direction().normalized()
	weapon.mover.add_impulse(kickback_strength * -direction)
