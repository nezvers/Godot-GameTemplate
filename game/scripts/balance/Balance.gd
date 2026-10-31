## Global gameplay balance, loaded once from res://game/balance/balance.json.
##
## Every balanced scene carries a BalanceBinding node. When the scene root enters
## the tree the binding asks this autoload to write the scene's JSON entry onto
## its components, before any child _enter_tree/_ready reads them. Entries are
## found by "scene" path, so inherited scenes resolve to their own entry.
##
## JSON keys are translated to node properties through the TABLES below:
##   "Selector/Selector:prop[:sub]"  set one property (sub walks into a Resource)
##   "Selector:*"                    JSON dict holds raw property names of that node
##   "@name:prop"                    property of ResourceNode item `name`
##   "...|damage" / "...|waves"      value converter (see _convert_special)
##   {"$each": {...}}                JSON dict of node name -> sub-entry
##   {...}                           JSON dict -> nested table on the same node
## A selector matches a descendant by node name or script name, "." is the root.
## Unknown JSON keys and missing nodes are reported with push_warning.
extends Node

const PATH:String = "res://game/balance/balance.json"
const INVENTORY_PATH:String = "res://addons/top_down/resources/ItemCollectionResource/weapon_inventory.tres"

## JSON category -> table name
const CATEGORY_TABLES:Dictionary = {
	"player": "actor",
	"enemies": "actor",
	"bosses": "actor",
	"weapons": "weapon",
	"projectiles": "projectile",
	"enemy_projectiles": "lob_projectile",
	"pickups": "pickup",
	"traps": "trap",
	"rooms": "room",
}

## Keys of an entry that describe it rather than tune it.
const META_KEYS:Array[String] = ["scene", "instance"]

const DAMAGE_DATA:Dictionary = {
	"damage": ".:damage_data_resource:base_damage|damage",
	"critical_chance": ".:damage_data_resource:critical_chance",
	"critical_multiply": ".:damage_data_resource:critical_multiply",
}

const TABLES:Dictionary = {
	"actor": {
		"health": ["@health:hp", "@health:max_hp", "@health:reset_hp", "@health:reset_max_hp"],
		"movement": "@movement:*",
		"resistances": "DamageSetup:resistance_list|damage",
		"hit_invulnerability": "DamageCooldown:cooldown_time",
		"dash": "DashAbility:*",
		"hole_damage": "HoleRecovery:hole_damage",
		"poison": "PoisonEffect:*",
		"slow": "SlowEffect:*",
		"stuck": "StuckEffect:*",
		## applied once at startup to the shared weapon inventory
		"max_weapons": "",
		"ai": "BotInput:*",
		"keep_distance": "KeepDistance:*",
		"lob": "EnemyLob:*",
		"split": "SlimeSplit:*",
		"crit_replace": "CriticalDamageReplace:*",
		"drop_chance": "ItemDrop:drop_chance",
		"melee": {
			"damage": "SlashAttack:damage_data_resource:base_damage|damage",
			"critical_chance": "SlashAttack:damage_data_resource:critical_chance",
			"critical_multiply": "SlashAttack:damage_data_resource:critical_multiply",
			"interval": "SlashAttack/ProjectileInterval:interval",
			"recoil": "SlashAttack/WeaponKickback:kickback_strength",
			"projectile": "SlashAttack/ProjectileSpawner:projectile_instance_resource",
		},
		## bosses
		"attack_loop": "BossAttackLoop:*",
		"damage_areas": {"$each": {
			"damage": "DamageDataTransmitter:transmission_resource:base_damage|damage",
			"critical_chance": "DamageDataTransmitter:transmission_resource:critical_chance",
			"critical_multiply": "DamageDataTransmitter:transmission_resource:critical_multiply",
			"kickback": "DamageDataTransmitter:transmission_resource:kickback_strength",
			"radius": ".:shape:radius",
		}},
		"jelly_ai": "BigJellyAi:*",
	},
	"weapon": {
		"interval": "ProjectileInterval:interval",
		"recoil": "WeaponKickback:kickback_strength",
		"projectile": "ProjectileSpawner:projectile_instance_resource",
		"projectile_angles": "ProjectileSpawner:projectile_angles",
		"random_spread": "SpreadShot:random_angle_offset",
		"initial_distance": "ProjectileSpawner:initial_distance",
		"damage": DAMAGE_DATA.damage,
		"critical_chance": DAMAGE_DATA.critical_chance,
		"critical_multiply": DAMAGE_DATA.critical_multiply,
	},
	"projectile": {
		"damage": "ProjectileSetup:base_damage|damage",
		"kickback": "ProjectileSetup:kickback",
		"speed": ".:speed",
		"lifetime": "ProjectileLifetime:time",
		"movement_type": "ProjectileMover:movement_type",
		"max_bounce": "ProjectileMover:max_bounce",
		"hit_limit": "HitLimit:target_hit_limit",
		"sub_projectile": "SubProjectileManager:start_projectile_instance_resource",
		"sub_projectile_angles": "ProjectileSpawner:projectile_angles",
	},
	"lob_projectile": {
		"damage": DAMAGE_DATA.damage,
		"critical_chance": DAMAGE_DATA.critical_chance,
		"critical_multiply": DAMAGE_DATA.critical_multiply,
		"kickback": "ProjectileSetup:kickback",
		"flight_time": ".:time",
		"landing_radius": "ShapeCastTransmitter2D:shape:radius",
		"on_land": "SpawnOnLand:*",
		"on_land_split": "JellySpawner:*",
	},
	"pickup": {
		"heal": "HealthDataTransmitter:transmission_resource:value",
	},
	"trap": {
		"lifetime": ".:lifetime",
		"fade_time": ".:fade_time",
	},
	"room": {
		"sections": {"$each": {
			"spawn_density": ".:spawn_density",
			"free_distance": ".:free_distance",
			"waves": ".:waves|waves",
		}},
		"spawn_points": {"$each": {
			"max_simultaneous": ".:max_simultaneous",
		}},
		"health_drop_chance": "DropManager:drop_chance",
	},
}

var data:Dictionary
## scene path -> [category, id]
var _by_scene:Dictionary

func _init()->void:
	_load()

func _ready()->void:
	var _player:Dictionary = data.get("player", {})
	if _player.has("max_weapons"):
		var _inventory:Resource = load(INVENTORY_PATH)
		_inventory.max_items = int(_player.max_weapons)

func _load()->void:
	data = {}
	_by_scene = {}
	if !FileAccess.file_exists(PATH):
		push_error("balance: missing ", PATH)
		return
	var _parsed:Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if !(_parsed is Dictionary):
		push_error("balance: ", PATH, " is not a valid JSON object")
		return
	data = _parsed
	for _category:String in CATEGORY_TABLES:
		var _section:Dictionary = data.get(_category, {})
		# player is a single entry, the rest are id -> entry
		if _section.has("scene"):
			_by_scene[_section.scene] = [_category, ""]
			continue
		for _id:String in _section:
			var _entry:Variant = _section[_id]
			if _entry is Dictionary && _entry.has("scene"):
				_by_scene[_entry.scene] = [_category, _id]

## Dotted lookup, e.g. value("difficulty.easy.enemy_health_ratio", 1.0)
func value(key:String, fallback:Variant = null)->Variant:
	var _current:Variant = data
	for _part:String in key.split("."):
		if !(_current is Dictionary) || !_current.has(_part):
			return fallback
		_current = _current[_part]
	return _current

## Difficulty ratio for a mode ("normal", "easy"); 1.0 when not set.
func ratio(mode:String, key:String)->float:
	return float(value("difficulty.%s.%s" % [mode, key], 1.0))

## Entry for a scene path: [category, id, entry] or [] when not balanced.
func entry_for_scene(scene_path:String)->Array:
	if !_by_scene.has(scene_path):
		return []
	var _found:Array = _by_scene[scene_path]
	var _entry:Dictionary = data[_found[0]] if _found[1].is_empty() else data[_found[0]][_found[1]]
	return [_found[0], _found[1], _entry]

## Writes the balance entry of `root`'s scene (or an explicit "category.id" key).
func apply_scene(root:Node, scene_path:String, key:String = "")->void:
	var _found:Array
	if key.is_empty():
		_found = entry_for_scene(scene_path)
	else:
		var _parts:PackedStringArray = key.split(".")
		var _entry:Variant = value(key)
		if _entry is Dictionary:
			_found = [_parts[0], _parts[1] if _parts.size() > 1 else "", _entry]
		else:
			push_warning("balance: no entry '%s' for %s" % [key, root.name])
	if _found.is_empty():
		return
	var _label:String = "%s.%s" % [_found[0], _found[1]]
	_apply_table(root, TABLES[CATEGORY_TABLES[_found[0]]], _found[2], _label, {})

## Resolves an id from "instances" or from an entry's "instance" path.
func instance_resource(id:String)->Resource:
	if id.begins_with("res://"):
		return load(id)
	var _instances:Dictionary = data.get("instances", {})
	if _instances.has(id):
		return load(_instances[id])
	for _category:String in CATEGORY_TABLES:
		var _section:Dictionary = data.get(_category, {})
		if _section.get(id) is Dictionary && _section[id].has("instance"):
			return load(_section[id].instance)
	push_warning("balance: unknown instance id '%s'" % id)
	return null

## Reverse of instance_resource, used to write ids back out.
func instance_id(resource:Resource)->String:
	if resource == null:
		return ""
	var _path:String = resource.resource_path
	var _instances:Dictionary = data.get("instances", {})
	for _id:String in _instances:
		if _instances[_id] == _path:
			return _id
	for _category:String in CATEGORY_TABLES:
		var _section:Dictionary = data.get(_category, {})
		for _id:String in _section:
			if _section[_id] is Dictionary && _section[_id].get("instance", "") == _path:
				return _id
	return _path

# --- applying -----------------------------------------------------------------

func _apply_table(base:Node, table:Dictionary, entry:Dictionary, label:String, duplicated:Dictionary)->void:
	for _key:String in entry:
		if _key in META_KEYS || _key.begins_with("_"):
			continue
		if !table.has(_key):
			push_warning("balance: unknown key '%s' in %s" % [_key, label])
			continue
		var _spec:Variant = table[_key]
		var _value:Variant = entry[_key]
		var _key_label:String = label + "." + _key
		if _spec is Dictionary:
			if !(_value is Dictionary):
				push_warning("balance: %s expects an object" % _key_label)
				continue
			if _spec.has("$each"):
				for _name:String in _value:
					var _node:Node = find(base, _name)
					if _node == null:
						push_warning("balance: %s: no node '%s'" % [_key_label, _name])
						continue
					_apply_table(_node, _spec["$each"], _value[_name], _key_label + "." + _name, duplicated)
			else:
				_apply_table(base, _spec, _value, _key_label, duplicated)
		elif _spec is Array:
			for _target:String in _spec:
				_apply_target(base, _target, _value, _key_label, duplicated)
		elif !(_spec as String).is_empty():
			_apply_target(base, _spec, _value, _key_label, duplicated)

func _apply_target(base:Node, spec:String, value:Variant, label:String, duplicated:Dictionary)->void:
	var _resolved:Array = resolve(base, spec, duplicated)
	if _resolved.is_empty():
		push_warning("balance: %s: target '%s' not found under %s" % [label, spec, base.name])
		return
	var _object:Object = _resolved[0]
	var _property:String = _resolved[1]
	var _converter:String = _resolved[2]
	if _property == "*":
		_apply_raw(_object, value, label, duplicated)
		return
	_set_property(_object, _property, value, _converter, label)

## Raw dictionary of property names; a key naming a child node recurses into it.
func _apply_raw(object:Object, value:Variant, label:String, duplicated:Dictionary)->void:
	if !(value is Dictionary):
		push_warning("balance: %s expects an object" % label)
		return
	for _key:String in value:
		if _key.begins_with("_"):
			continue
		if _key in object:
			_set_property(object, _key, value[_key], "", label + "." + _key)
		elif object is Node && value[_key] is Dictionary && find(object, _key) != null:
			_apply_raw(find(object, _key), value[_key], label + "." + _key, duplicated)
		else:
			push_warning("balance: %s: '%s' has no property '%s'" % [label, _object_name(object), _key])

## Turns a spec into [object, property, converter]. Node-held resources on the
## way are duplicated once, so a scene sub-resource shared with other scenes
## (e.g. the common zombie_attack weapon) is never written for all of them.
## ResourceNode items are written in place: ResourceNode duplicates them itself.
## With for_write false nothing is duplicated (reading scene values).
func resolve(base:Node, spec:String, duplicated:Dictionary = {}, for_write:bool = true)->Array:
	var _converter:String = ""
	if spec.contains("|"):
		_converter = spec.get_slice("|", 1)
		spec = spec.get_slice("|", 0)
	var _parts:PackedStringArray = spec.split(":")
	var _object:Object
	var _from_resource_node:bool = spec.begins_with("@")
	if _from_resource_node:
		_object = _resource_node_item(base, _parts[0].substr(1))
	else:
		_object = find(base, _parts[0])
	if _object == null:
		return []
	for i:int in range(1, _parts.size() - 1):
		var _property:String = _parts[i]
		if !(_property in _object):
			return []
		var _sub:Variant = _object.get(_property)
		if !(_sub is Resource):
			return []
		if for_write && !_from_resource_node && !duplicated.has(_sub.get_instance_id()):
			_sub = _sub.duplicate(true)
			duplicated[_sub.get_instance_id()] = true
			_object.set(_property, _sub)
		_object = _sub
	var _last:String = _parts[_parts.size() - 1]
	if _last != "*" && !(_last in _object):
		return []
	return [_object, _last, _converter]

## Selector path: each "/" segment is the first descendant (breadth first) whose
## name or script name matches; "." is the base itself.
func find(base:Node, selector:String)->Node:
	var _node:Node = base
	for _segment:String in selector.split("/"):
		if _segment == ".":
			continue
		_node = _find_descendant(_node, _segment)
		if _node == null:
			return null
	return _node

func _find_descendant(base:Node, segment:String)->Node:
	var _queue:Array[Node] = base.get_children(true)
	while !_queue.is_empty():
		var _node:Node = _queue.pop_front()
		if _node.name == segment || _script_name(_node) == segment:
			return _node
		_queue.append_array(_node.get_children(true))
	return null

func _script_name(object:Object)->String:
	var _script:Script = object.get_script()
	if _script == null:
		return ""
	var _global:String = _script.get_global_name()
	return _global if !_global.is_empty() else _script.resource_path.get_file().get_basename()

func _object_name(object:Object)->String:
	return object.name if object is Node else _script_name(object)

func _resource_node_item(base:Node, item_name:String)->Resource:
	var _resource_node:Node = base.get_node_or_null("ResourceNode")
	if _resource_node == null:
		_resource_node = find(base, "ResourceNode")
	if _resource_node == null:
		return null
	for _item:Resource in _resource_node.list:
		if _item.resource_name == item_name:
			return _item.resource
	return null

func _set_property(object:Object, property:String, value:Variant, converter:String, label:String)->void:
	var _new:Variant
	if !converter.is_empty():
		_new = _convert_special(converter, value, label)
	else:
		_new = _convert(object, property, value, label)
	if _new == null && value != null:
		return
	object.set(property, _new)

func _convert_special(converter:String, value:Variant, label:String)->Variant:
	match converter:
		"damage":
			return damage_list(value)
		"waves":
			return _waves(value, label)
	push_warning("balance: %s: unknown converter '%s'" % [label, converter])
	return null

## Converts a JSON value to the type of the current property value.
func _convert(object:Object, property:String, value:Variant, label:String)->Variant:
	var _current:Variant = object.get(property)
	match typeof(_current):
		TYPE_INT:
			if value is String:
				return _enum_value(object, value, label)
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return bool(value)
		TYPE_STRING:
			return str(value)
		TYPE_STRING_NAME:
			return StringName(value)
		TYPE_VECTOR2:
			return Vector2(value[0], value[1])
		TYPE_ARRAY:
			if !_current.is_typed():
				return value.duplicate()
			var _array:Array = Array([], _current.get_typed_builtin(), _current.get_typed_class_name(), _current.get_typed_script())
			for _item:Variant in value:
				match _current.get_typed_builtin():
					TYPE_INT:
						_array.append(int(_item))
					TYPE_FLOAT:
						_array.append(float(_item))
					TYPE_OBJECT:
						_array.append(instance_resource(_item))
					_:
						_array.append(_item)
			return _array
		TYPE_OBJECT, TYPE_NIL:
			if value is String:
				return instance_resource(value) if !value.is_empty() else null
	push_warning("balance: %s: can't convert %s for '%s'" % [label, type_string(typeof(value)), property])
	return null

func _enum_value(object:Object, name:String, label:String)->int:
	var _script:Script = object.get_script()
	while _script != null:
		for _constant:Variant in _script.get_script_constant_map().values():
			if _constant is Dictionary && _constant.has(name):
				return _constant[name]
		_script = _script.get_base_script()
	push_warning("balance: %s: unknown enum value '%s'" % [label, name])
	return 0

## 10 -> 10 PHYSICAL, {"FIRE": 4, "PHYSICAL": 2} -> both, 0 -> none.
func damage_list(value:Variant)->Array[DamageTypeResource]:
	var _list:Array[DamageTypeResource] = []
	var _values:Dictionary = value if value is Dictionary else {"PHYSICAL": value}
	for _type:String in _values:
		if float(_values[_type]) == 0.0:
			continue
		var _damage:DamageTypeResource = DamageTypeResource.new()
		_damage.type = DamageTypeResource.DamageType[_type]
		_damage.value = float(_values[_type])
		_list.append(_damage)
	return _list

func _waves(value:Variant, label:String)->Array[SpawnWaveList]:
	var _list:Array[SpawnWaveList] = []
	for _wave_data:Dictionary in value:
		var _wave:SpawnWaveList = SpawnWaveList.new()
		_wave.count = int(_wave_data.get("count", 1))
		_wave.max_alive = int(_wave_data.get("max_alive", 0))
		_wave.is_boss = bool(_wave_data.get("is_boss", false))
		_wave.display_name = str(_wave_data.get("display_name", ""))
		for _id:String in _wave_data.get("enemies", []):
			var _instance:Resource = instance_resource(_id)
			if _instance != null:
				_wave.instance_list.append(_instance)
		if _wave.instance_list.is_empty():
			push_warning("balance: %s: wave without enemies" % label)
		_list.append(_wave)
	return _list
