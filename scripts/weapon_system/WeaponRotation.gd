## Sets weapon direction relative to mouse position
class_name WeaponRotation
extends Node2D

@export var weapon:Weapon
## Rotates weapon and it's shooting direction
@export var rotate_node:Node2D
## preserve weapons visuals by keeping it's bottom down
@export var flip_horizontally:bool = true


func _process(_delta:float)->void:
	var direction:Vector2 = weapon.mover.input_resource.aim_direction
	if flip_horizontally && direction.x != 0.0:
		rotate_node.scale.y = sign(direction.x)
	rotate_node.rotation = direction.angle()
