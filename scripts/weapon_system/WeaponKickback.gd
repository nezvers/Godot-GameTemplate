class_name WeaponKickback
extends Node

@export var weapon_trigger:WeaponTrigger
@export var weapon:Weapon
@export var kickback_strength:float

var push_resource:PushResource

func _ready()->void:
	push_resource = weapon.resource_node.get_resource("push")
	weapon_trigger.shoot_event.connect(apply_kickback)

func apply_kickback()->void:
	var direction:Vector2 = weapon_trigger.get_direction().normalized()
	push_resource.add_impulse(kickback_strength * -direction)
