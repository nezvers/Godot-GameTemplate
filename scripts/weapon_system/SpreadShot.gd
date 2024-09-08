class_name SpreadShot
extends Node

@export var weapon:Weapon
@export_range(0.0, 180.0) var random_angle_offset:float

## Angles from weapon are duplicated and used as reference angles
var stored_projectile_angles:Array[float] = [0.0]


func _ready()->void:
	stored_projectile_angles = weapon.projectile_angles.duplicate()
	weapon.prepare_spawn.connect(on_prepare_spawn)

func on_prepare_spawn()->void:
	for i:int in stored_projectile_angles.size():
		var rand_angle:float = randf_range(-random_angle_offset, random_angle_offset)
		weapon.projectile_angles[i] = stored_projectile_angles[i] + rand_angle
