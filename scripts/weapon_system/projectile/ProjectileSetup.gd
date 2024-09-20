extends Node

@export var projectile:Projectile2D
@export var area_transmitter:AreaTransmitter2D
@export var damage_transmitter:DamageTransmitter


func _ready()->void:
	var damage_resource:DamageResource = projectile.damage_resource
	# fill last values that projectile is controlling
	damage_resource.kickback_strength = projectile.kickback_strength
	damage_resource.projectile_multiply = projectile.damage_multiply
	damage_resource.initialize_generation()
	
	area_transmitter.collision_mask = Bitwise.append_flags(area_transmitter.collision_mask, projectile.collision_mask)
	damage_transmitter.damage_resource = damage_resource
	damage_transmitter.hit.connect(on_hit)

## Process each hit damage direction
func on_hit()->void:
	projectile.damage_resource.direction = projectile.direction

func on_prepare_exit()->void:
	area_transmitter.set_monitoring.call_deferred(false)
