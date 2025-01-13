class_name ProjectileSetup
extends Node

@export var base_damage:Array[DamageTypeResource]
@export var status_damage:Array[DamageStatusResource]
@export var kickback:float

@export_category("References")
@export var projectile:Projectile2D
@export var area_transmitter:AreaTransmitter2D
@export var data_channel_transmitter:DataChannelTransmitter


# TODO: move what's possible into it's own ResourceNode
func _ready()->void:
	var _damage_data_resource:DamageDataResource = projectile.damage_data_resource
	
	area_transmitter.collision_mask = Bitwise.append_flags(area_transmitter.collision_mask, projectile.collision_mask)
	
	data_channel_transmitter.transmission_resource = _damage_data_resource
	if !data_channel_transmitter.update_requested.is_connected(_on_update_requested):
		data_channel_transmitter.update_requested.connect(_on_update_requested)

## Process each hit damage direction when it is applying damage to a target
func _on_update_requested(transmission_resource:TransmissionResource)->void:
	var _damage_data_resource:DamageDataResource = transmission_resource
	
	## TODO: something similar but create a new DamageDataResource only when needed
	_damage_data_resource.direction = projectile.direction
	_damage_data_resource.kickback_strength = kickback
	_damage_data_resource.base_damage.append_array(base_damage)
	_damage_data_resource.status_list.append_array(status_damage)
