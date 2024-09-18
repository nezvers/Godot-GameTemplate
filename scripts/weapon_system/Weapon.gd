class_name Weapon
extends Node2D

signal enabled_changed

## Toggle weapons visibility and capability to spawn projectile
@export var enabled:bool = true
## Gun will set projectile collision_mask with this value
@export_flags_2d_physics var collision_mask:int
## Reference to mover to access input resource
@export var mover:MoverTopDown2D
## Used for defining projectile damage
@export var damage_resource:DamageResource

func _ready()->void:
	set_enabled(enabled)

## Toggle connections to the action input and controls visibility
func set_enabled(value:bool)->void:
	enabled = value
	visible = enabled
	enabled_changed.emit(enabled)
