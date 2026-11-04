## Meta-upgrade graph, loaded once from res://game/balance/upgrades.json.
##
## Each node has a grid `pos`, an `icon`, a `title` and `text`, a `cost` item list
## (LootItems format), `requires` (any one owned node unlocks it) and `effects`
## (stat key -> amount, summed over every owned node). `keystone` nodes get the
## golden frame. `labels` are branch names drawn faintly on the graph, at grid positions.
## `trees` are separate graphs shown one at a time (the main tree and its sister
## HORDE tree of enemy buffs). Each has a `root` that is free and always owned;
## nodes and labels name their tree with `tree`, "main" when left out.
## Unknown stats, icons and requires ids are reported with push_warning.
class_name MetaUpgrades

const PATH:String = "res://game/balance/upgrades.json"
## Root of the main tree.
const ROOT:String = "root"
const MAIN_TREE:String = "main"

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
	"spawn_rate_ratio": "percent",
	"wave_count_ratio": "percent",
	"spawner_count": "flat",
	"timed_spawners": "flat",
	"loot_ratio": "percent",
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

## Tree id -> {"title", "root"}, the main tree first.
static func trees()->Dictionary:
	return data().get("trees", {MAIN_TREE: {"title": "UPGRADES", "root": ROOT}})

static func tree_ids()->Array:
	return trees().keys()

static func tree_title(tree:String)->String:
	return trees().get(tree, {}).get("title", tree.to_upper())

static func tree_root(tree:String)->String:
	return trees().get(tree, {}).get("root", "")

static func tree_of(id:String)->String:
	return node(id).get("tree", MAIN_TREE)

static func is_root(id:String)->bool:
	for _tree:String in trees():
		if tree_root(_tree) == id:
			return true
	return false

## Node ids of one tree.
static func nodes_in(tree:String)->Array[String]:
	var _ids:Array[String] = []
	for _id:String in nodes():
		if tree_of(_id) == tree:
			_ids.append(_id)
	return _ids

## [{"text", "pos"}] branch names on one tree's graph.
static func labels(tree:String = MAIN_TREE)->Array:
	return data().get("labels", []).filter(func (label:Dictionary)->bool: return label.get("tree", MAIN_TREE) == tree)

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
	var _trees:Dictionary = _parsed.get("trees", {})
	for _tree:String in _trees:
		if !_nodes.has(_trees[_tree].get("root", "")):
			push_warning("upgrades: tree %s has no root node" % _tree)
	for _id:String in _nodes:
		var _entry:Dictionary = _nodes[_id]
		var _tree:String = _entry.get("tree", MAIN_TREE)
		if _tree != MAIN_TREE && !_trees.has(_tree):
			push_warning("upgrades: %s is in unknown tree '%s'" % [_id, _tree])
		if !ICONS.has(_entry.get("icon", "")):
			push_warning("upgrades: %s has unknown icon '%s'" % [_id, _entry.get("icon", "")])
		for _required:String in _entry.get("requires", []):
			if !_nodes.has(_required):
				push_warning("upgrades: %s requires unknown node '%s'" % [_id, _required])
			elif _nodes[_required].get("tree", MAIN_TREE) != _tree:
				push_warning("upgrades: %s requires '%s' from another tree" % [_id, _required])
		for _key:String in _entry.get("effects", {}):
			if !STATS.has(_key):
				push_warning("upgrades: %s has unknown stat '%s'" % [_id, _key])
	return _parsed
