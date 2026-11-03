## Meta-upgrade graph, loaded once from res://game/balance/upgrades.json.
##
## Each node has a grid `pos`, an `icon`, a `title` and `text`, a `cost` item list
## (LootItems format), `requires` (any one owned node unlocks it) and `effects`
## (stat key -> amount, summed over every owned node). `keystone` nodes get the
## golden frame. "root" is free and always owned. `labels` are branch names
## drawn faintly on the graph, at grid positions.
## Unknown stats, icons and requires ids are reported with push_warning.
class_name MetaUpgrades

const PATH:String = "res://game/balance/upgrades.json"
const ROOT:String = "root"

## Stat key -> how its amount reads in a node's text ("{max_hp}" -> "+10").
##   "flat" +N, "seconds" +Ns, "percent" +N%, "less_percent" -N%
const STATS:Dictionary = {
	"max_hp": "flat",
	"hit_invulnerability": "seconds",
	"damage_ratio": "percent",
	"speed_ratio": "percent",
	"dash_cooldown_ratio": "less_percent",
	"start_coin": "flat",
	"start_meat": "flat",
	"start_slime": "flat",
}

## Frame order of meta_icons_12x12_strip10.png (set by generate_meta_frames.py).
const ICONS:Array[String] = ["star", "heart", "sword", "boot", "dash", "shield", "coin", "meat", "slime", "crystal"]

static var _data:Dictionary

static func data()->Dictionary:
	if _data.is_empty():
		_data = _load()
	return _data

static func nodes()->Dictionary:
	return data().get("nodes", {})

static func node(id:String)->Dictionary:
	return nodes().get(id, {})

## [{"text", "pos"}] branch names on the graph.
static func labels()->Array:
	return data().get("labels", [])

## Pixels per grid cell.
static func grid()->float:
	return float(data().get("grid", 36))

static func position(id:String)->Vector2:
	var _pos:Array = node(id).get("pos", [0, 0])
	return Vector2(_pos[0], _pos[1]) * grid()

static func requires(id:String)->Array:
	return node(id).get("requires", [])

static func cost(id:String)->Array:
	return node(id).get("cost", [])

static func effects(id:String)->Dictionary:
	return node(id).get("effects", {})

static func is_keystone(id:String)->bool:
	return node(id).get("keystone", false)

static func icon_index(id:String)->int:
	return maxi(ICONS.find(node(id).get("icon", "star")), 0)

## The node's text with every "{stat}" replaced by its formatted amount.
static func describe(id:String)->String:
	var _text:String = node(id).get("text", "")
	var _effects:Dictionary = effects(id)
	for _key:String in _effects:
		_text = _text.replace("{%s}" % _key, format_stat(_key, _effects[_key]))
	return _text

static func format_stat(key:String, amount:float)->String:
	match STATS.get(key, "flat"):
		"seconds":
			return "+%ss" % _number(amount)
		"percent":
			return "+%s%%" % _number(amount * 100.0)
		"less_percent":
			return "-%s%%" % _number(amount * 100.0)
	return "+%s" % _number(amount)

static func _number(value:float)->String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.01))

static func _load()->Dictionary:
	var _parsed:Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if !(_parsed is Dictionary):
		push_warning("upgrades: %s didn't parse" % PATH)
		return {}
	var _nodes:Dictionary = _parsed.get("nodes", {})
	if !_nodes.has(ROOT):
		push_warning("upgrades: no '%s' node" % ROOT)
	for _id:String in _nodes:
		var _entry:Dictionary = _nodes[_id]
		if !ICONS.has(_entry.get("icon", "")):
			push_warning("upgrades: %s has unknown icon '%s'" % [_id, _entry.get("icon", "")])
		for _required:String in _entry.get("requires", []):
			if !_nodes.has(_required):
				push_warning("upgrades: %s requires unknown node '%s'" % [_id, _required])
		for _key:String in _entry.get("effects", {}):
			if !STATS.has(_key):
				push_warning("upgrades: %s has unknown stat '%s'" % [_id, _key])
	return _parsed
