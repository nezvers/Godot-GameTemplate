class_name Weapon
extends Node2D

signal enabled_changed

## Toggle weapons visibility and capability to spawn projectile
@export var enabled:bool = true

## Gun will set projectile collision_mask with this value
@export_flags_2d_physics var collision_mask:int

## Reference to ResourceNode to access an input resource
@export var resource_node:ResourceNode

# TODO: Store it somewhere better and when set as active plant in users resource_node to connect the damage chain.
# TODO: Support multiple active weapons.
## Used for defining projectile damage
@export var damage_data_resource:DamageDataResource

func _ready()->void:
	set_enabled(enabled)
	
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	assert(_damage_resource != null)
	damage_data_resource.report_callback = _damage_resource.report
	
	request_ready()

## Toggle connections to the action input and controls visibility
func set_enabled(value:bool)->void:
	enabled = value
	visible = enabled
	enabled_changed.emit(enabled)
