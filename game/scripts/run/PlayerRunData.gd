## One player's part of a run checkpoint (RunSave.players). Plain data only:
## weapons are stored by name and looked up again in weapon_database, so a changed
## database can't break a save.
class_name PlayerRunData
extends Resource

## Stable per-install id (PlayerProfile); matches a rejoining co-op player to their data.
@export var profile_id:String
@export var display_name:String
## Co-op slot 0..7; 0 is the host / single player.
@export var slot:int

@export var hp:float
@export var max_hp:float
@export var downed:bool

## Inventory weapon names (ItemResource.resource_name) and the selected index.
@export var weapons:PackedStringArray
@export var selected:int
## Weapon scene_path -> level bought at the slime workbench.
@export var weapon_levels:Dictionary
## Loot item id (LootItems.COUNTERS, not boss_crystal) -> {"value", "collected_total"}.
@export var wallet:Dictionary

const MAX_WEAPONS:int = 16
const MAX_TEXT:int = 64

## Plain values for the network (co-op guests send theirs to the host).
func to_dict()->Dictionary:
	return {"hp": hp, "max_hp": max_hp, "weapons": weapons, "selected": selected,
		"weapon_levels": weapon_levels, "wallet": wallet}

## Validated copy of to_dict() data from a peer; null when it doesn't fit.
static func from_dict(data:Dictionary)->PlayerRunData:
	var _out:PlayerRunData = PlayerRunData.new()
	if typeof(data.get("hp")) != TYPE_FLOAT || typeof(data.get("max_hp")) != TYPE_FLOAT || typeof(data.get("selected")) != TYPE_INT:
		return null
	if typeof(data.get("weapons")) != TYPE_PACKED_STRING_ARRAY || typeof(data.get("weapon_levels")) != TYPE_DICTIONARY || typeof(data.get("wallet")) != TYPE_DICTIONARY:
		return null
	_out.max_hp = clampf(data.max_hp, 1.0, 100000.0)
	_out.hp = clampf(data.hp, 0.0, _out.max_hp)
	_out.selected = clampi(data.selected, 0, MAX_WEAPONS)
	var _weapons:PackedStringArray = data.weapons
	if _weapons.size() > MAX_WEAPONS:
		return null
	for _name:String in _weapons:
		if _name.length() > MAX_TEXT:
			return null
	_out.weapons = _weapons
	var _levels:Dictionary = data.weapon_levels
	if _levels.size() > 64:
		return null
	for _key:Variant in _levels:
		if typeof(_key) != TYPE_STRING || (_key as String).length() > 200 || typeof(_levels[_key]) != TYPE_INT:
			return null
	_out.weapon_levels = _levels.duplicate()
	var _wallet:Dictionary = data.wallet
	if _wallet.size() > 8:
		return null
	for _key:Variant in _wallet:
		var _entry:Variant = _wallet[_key]
		if typeof(_key) != TYPE_STRING || typeof(_entry) != TYPE_DICTIONARY:
			return null
		_out.wallet[_key] = {"value": int((_entry as Dictionary).get("value", 0)), "collected_total": int((_entry as Dictionary).get("collected_total", 0))}
	return _out
