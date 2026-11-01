## Run-scoped weapon upgrade levels bought at the slime workbench.
## Keyed by weapon scene path, the same id the inventory and WeaponManager use.
class_name WeaponUpgradeResource
extends Resource

signal updated

@export var max_level:int = 3
## Added to the damage multiplier per level.
@export var damage_per_level:float = 0.2
## Taken off the fire interval multiplier per level.
@export var interval_per_level:float = 0.1

## scene_path -> level
var levels:Dictionary = {}

func get_level(scene_path:String)->int:
	return levels.get(scene_path, 0)

func can_upgrade(scene_path:String)->bool:
	return !scene_path.is_empty() && get_level(scene_path) < max_level

func upgrade(scene_path:String)->bool:
	if !can_upgrade(scene_path):
		return false
	levels[scene_path] = get_level(scene_path) + 1
	updated.emit()
	return true

func damage_multiplier(scene_path:String)->float:
	return 1.0 + get_level(scene_path) * damage_per_level

func interval_multiplier(scene_path:String)->float:
	return maxf(1.0 - get_level(scene_path) * interval_per_level, 0.2)

func reset_resource()->void:
	levels.clear()
	updated.emit()
