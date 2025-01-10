class_name WeaponKickback
extends Node

## Node having access to user's ResourceNode
@export var weapon:Weapon

## Node for weapons direction information
@export var weapon_trigger:WeaponTrigger

## Kickback applied to user's PushResource
@export var kickback_strength:float

## Weapon user's PushResource
var push_resource:PushResource

func _ready()->void:
	push_resource = weapon.resource_node.get_resource("push")
	if !weapon_trigger.shoot_event.is_connected(apply_kickback):
		weapon_trigger.shoot_event.connect(apply_kickback)
	
	# when using with pool node
	request_ready()

## Give kickback push to user's PushResource
func apply_kickback()->void:
	var direction:Vector2 = weapon_trigger.get_direction().normalized()
	push_resource.add_impulse(kickback_strength * -direction)
