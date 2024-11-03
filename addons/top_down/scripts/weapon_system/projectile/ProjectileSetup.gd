extends Node

@export var projectile:Projectile2D
@export var area_transmitter:AreaTransmitter2D
@export var data_transmitter:DataTransmitter


# TODO: move what's possible into it's own ResourceNode
func _ready()->void:
	var damage_resource:DamageResource = projectile.damage_resource
	# fill last values that projectile is controlling
	damage_resource.kickback_strength = projectile.kickback_strength
	damage_resource.projectile_multiply = projectile.damage_multiply
	damage_resource.initialize_generation()
	
	area_transmitter.collision_mask = Bitwise.append_flags(area_transmitter.collision_mask, projectile.collision_mask)
	data_transmitter.transmission_resource = damage_resource
	if !data_transmitter.update_requested.is_connected(on_update_requested):
		data_transmitter.update_requested.connect(on_update_requested)

## Process each hit damage direction when it is applying damage to a target
func on_update_requested(transmission_resource:TransmissionResource)->void:
	(transmission_resource as DamageResource).direction = projectile.direction

func on_prepare_exit()->void:
	area_transmitter.set_monitoring.call_deferred(false)
