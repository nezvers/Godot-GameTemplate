class_name SpriteFlip
extends Node

@export var mover_2d:MoverTopDown2D
## Node that is used for flipping visuals horizontally
@export var flip_node:Node2D

enum FlipType {WALK_DIR, AIM_DIR}
## Choose sprite flipping is related to walking or aiming
@export var flip_type:FlipType

## 1 = Right, -1 = Left
var dir:int = 1

func _process(_delta:float)->void:
	var new_dir:int
	match flip_type:
		FlipType.WALK_DIR:
			new_dir = sign(mover_2d.input_resource.axis.x)
		FlipType.AIM_DIR:
			new_dir = sign(mover_2d.input_resource.aim_direction.x)
	
	if new_dir == 0:
		return
	if new_dir == dir:
		return
	dir = new_dir
	flip_node.scale.x = dir