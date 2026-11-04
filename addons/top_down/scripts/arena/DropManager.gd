class_name DropManager
extends Node

## Arena sections whose enemy kills drop loot.
@export var sections:Array[ArenaSection]

## Scales every chance from the killed enemy's balance "drops" (rooms.<id>.loot_multiplier).
@export var loot_multiplier:float = 1.0

## Horde meta-upgrades pay back with loot_ratio.
const META:MetaUpgradeResource = preload("res://game/resources/meta_upgrade_resource.tres")
## Not scaled by loot_ratio, so buying upgrades can't snowball into more crystals.
const UNSCALED:Array[String] = ["boss_crystal"]

func _ready()->void:
	for _section:ArenaSection in sections:
		if _section == null:
			continue
		_section.enemy_killed.connect(_on_killed)

func _on_killed(enemy:ActiveEnemy)->void:
	var _position:Vector2 = enemy.owner.global_position
	var _drops:Dictionary = enemy_drops(enemy.owner.scene_file_path)
	var _meta_ratio:float = 1.0 + META.stat("loot_ratio")
	# Each item rolls on its own
	for _id:String in _drops:
		var _ratio:float = loot_multiplier if UNSCALED.has(_id) else loot_multiplier * _meta_ratio
		LootItems.spawn(_id, LootItems.roll_count(float(_drops[_id]) * _ratio, randf()), _position)

## Item id -> chance from enemies.<id>.drops / bosses.<id>.drops.
static func enemy_drops(scene_path:String)->Dictionary:
	var _found:Array = Balance.entry_for_scene(scene_path)
	if _found.is_empty():
		return {}
	return _found[2].get("drops", {})
