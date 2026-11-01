## Run-scoped weapon upgrade levels bought at the slime workbench.
## Keyed by weapon scene path, the same id the inventory and WeaponManager use.
## Each weapon's levels come from weapons.<id>.upgrades in balance.json:
##   [{"cost": [{"item": "slime", "amount": 2}], "damage": 1.2, "interval": 0.9}, ...]
## damage and interval are the multipliers at that level, not steps.
class_name WeaponUpgradeResource
extends Resource

signal updated

## scene_path -> level
var levels:Dictionary = {}

func get_level(scene_path:String)->int:
	return levels.get(scene_path, 0)

func upgrade_table(scene_path:String)->Array:
	var _found:Array = Balance.entry_for_scene(scene_path)
	if _found.is_empty():
		return []
	return _found[2].get("upgrades", [])

func max_level(scene_path:String)->int:
	return upgrade_table(scene_path).size()

func can_upgrade(scene_path:String)->bool:
	return !scene_path.is_empty() && get_level(scene_path) < max_level(scene_path)

## The level that would be bought next, or empty when maxed.
func next_upgrade(scene_path:String)->Dictionary:
	var _table:Array = upgrade_table(scene_path)
	var _level:int = get_level(scene_path)
	return _table[_level] if _level < _table.size() else {}

func upgrade(scene_path:String)->bool:
	if !can_upgrade(scene_path):
		return false
	levels[scene_path] = get_level(scene_path) + 1
	updated.emit()
	return true

func damage_multiplier(scene_path:String)->float:
	return _current_value(scene_path, "damage")

func interval_multiplier(scene_path:String)->float:
	return maxf(_current_value(scene_path, "interval"), 0.05)

func _current_value(scene_path:String, key:String)->float:
	var _level:int = get_level(scene_path)
	if _level == 0:
		return 1.0
	var _table:Array = upgrade_table(scene_path)
	return float(_table[mini(_level, _table.size()) - 1].get(key, 1.0))

func reset_resource()->void:
	levels.clear()
	updated.emit()
