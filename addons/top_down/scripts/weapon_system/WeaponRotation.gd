## Sets weapon direction relative to mouse position
class_name WeaponRotation
extends Node

@export var weapon:Weapon

## Rotates weapon and it's shooting direction
@export var rotate_node:Node2D

## preserve weapons visuals by keeping it's bottom down
@export var flip_vertically:bool = true

## used to flip scale only when changed
var current_flip:int = 1

var input_resource:InputResource

func _ready()->void:
	input_resource = weapon.resource_node.get_resource("input")

func _process(_delta:float)->void:
	var direction:Vector2 = input_resource.aim_direction
	var dir_x:int = sign(direction.x)
	if flip_vertically && (dir_x != 0 && dir_x != current_flip):
		current_flip = dir_x
		rotate_node.scale.y = current_flip
	rotate_node.rotation = direction.angle()
