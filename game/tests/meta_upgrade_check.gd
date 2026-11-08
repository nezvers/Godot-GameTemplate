## Checks the meta-upgrades: upgrades.json (requires ids, reachability from each
## tree's root, no links between trees, costs, stats, icons), MetaUpgradeResource (states, buying, refunds, save
## round trip), the title's Upgrades button showing once a crystal was picked up,
## the screen (a button per node with the right frame, focus walking every node
## of the shown tree, switching to the HORDE tree, buying through a button) and the effects on a new run's player and items.
## Saves go to temporary files; the real crystal and upgrade saves are untouched.
##   Godot --headless --path . res://game/tests/meta_upgrade_check.tscn
## With a display, saves a screenshot of the screen instead:
##   Godot --path . res://game/tests/meta_upgrade_check.tscn -- shot <out.png> [node id]
extends Node

const SCENES:String = "res://game/scenes/"
const TD:String = "res://addons/top_down/"
const SCREEN:String = SCENES + "meta_upgrades.tscn"

var failures:int = 0
var checks:int = 0
var _meta:MetaUpgradeResource
var _crystals:ScoreResource
var _names:Dictionary

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	_meta = load("res://game/resources/meta_upgrade_resource.tres")
	_crystals = load(TD + "resources/global_resources/boss_crystal_resource.tres")
	_use_temp_saves()

	var _args:PackedStringArray = OS.get_cmdline_user_args()
	if _args.size() > 1 && _args[0] == "shot":
		await _shot(_args[1], _args[2] if _args.size() > 2 else "vitality_2")
	else:
		_check_data()
		_check_resource()
		await _check_entry()
		await _check_screen()
		await _check_effects()
		print("meta_upgrade_check: %d checks, %d failures" % [checks, failures])
	_restore_saves()
	get_tree().quit(1 if failures > 0 else 0)

## The victory screen saves the New Game+ unlock, so the campaign gets a temp save too.
func _use_temp_saves()->void:
	var _campaign:CampaignResource = load("res://game/resources/campaign_resource.tres")
	_campaign.ng_plus_unlocked = true
	for _resource:SaveableResource in [_meta, _crystals, _campaign]:
		_names[_resource] = _resource.resource_name
		_resource.resource_name = "MetaCheck" + _resource.resource_name
		_resource.is_loaded = true
	_meta.reset_resource()
	_crystals.reset_resource()

func _restore_saves()->void:
	for _resource:SaveableResource in _names:
		_resource.delete_resource()
		_resource.resource_name = _names[_resource]

func _check_data()->void:
	var _nodes:Dictionary = MetaUpgrades.nodes()
	check(_nodes.has(MetaUpgrades.ROOT), "upgrades.json has a root")
	check(MetaUpgrades.tree_root(MetaUpgrades.MAIN_TREE) == MetaUpgrades.ROOT, "the main tree starts at the root")
	check(MetaUpgrades.tree_ids().has("horde"), "the HORDE sister tree exists")
	for _tree:String in MetaUpgrades.tree_ids():
		var _root:String = MetaUpgrades.tree_root(_tree)
		check(_nodes.has(_root) && MetaUpgrades.tree_of(_root) == _tree, "tree %s has its root %s" % [_tree, _root])
		check(MetaUpgrades.cost(_root).is_empty(), "the %s root is free" % _tree)
	var _cells:Dictionary = {}
	for _id:String in _nodes:
		var _node:Dictionary = _nodes[_id]
		check(MetaUpgrades.ICONS.has(_node.get("icon", "")), "%s has a known icon" % _id)
		check(!_node.get("title", "").is_empty() && _node.has("text"), "%s has a title and text" % _id)
		check(MetaUpgrades.trees().has(MetaUpgrades.tree_of(_id)), "%s is in a known tree" % _id)
		var _cell:Array = [MetaUpgrades.tree_of(_id), MetaUpgrades.position(_id)]
		check(!_cells.has(_cell), "%s doesn't sit on %s" % [_id, _cells.get(_cell, "")])
		_cells[_cell] = _id
		for _required:String in MetaUpgrades.requires(_id):
			check(_nodes.has(_required), "%s requires an existing node (%s)" % [_id, _required])
			check(MetaUpgrades.tree_of(_required) == MetaUpgrades.tree_of(_id), "%s requires %s from its own tree" % [_id, _required])
		for _key:String in MetaUpgrades.effects(_id):
			check(MetaUpgrades.STATS.has(_key), "%s uses a known stat (%s)" % [_id, _key])
		check(!MetaUpgrades.describe(_id).contains("{"), "%s text fills every placeholder" % _id)
		if MetaUpgrades.is_root(_id):
			continue
		check(!MetaUpgrades.requires(_id).is_empty(), "%s requires something" % _id)
		check(!MetaUpgrades.cost(_id).is_empty(), "%s costs something" % _id)
		for _entry:Dictionary in MetaUpgrades.cost(_id):
			check(LootItems.COUNTERS.has(_entry.get("item", "")), "%s costs a known item" % _id)
	# Every node reachable from a root through requires (links stay in one tree).
	var _reached:Dictionary = {}
	for _tree:String in MetaUpgrades.tree_ids():
		_reached[MetaUpgrades.tree_root(_tree)] = true
	var _grew:bool = true
	while _grew:
		_grew = false
		for _id:String in _nodes:
			if _reached.has(_id):
				continue
			for _required:String in MetaUpgrades.requires(_id):
				if _reached.has(_required):
					_reached[_id] = true
					_grew = true
					break
	for _id:String in _nodes:
		check(_reached.has(_id), "%s is reachable from the root" % _id)
	check(MetaUpgrades.format_stat("damage_ratio", 0.1) == "+10%", "ratios read as percent")
	check(MetaUpgrades.format_stat("dash_cooldown_ratio", 0.15) == "-15%", "cooldown cuts read as minus percent")
	check(MetaUpgrades.format_stat("hit_invulnerability", 0.2) == "+0.2s", "seconds read with s")
	check(MetaUpgrades.format_stat("spawn_rate_ratio", 1.0) == "+100%", "spawn rate reads as percent")
	check(MetaUpgrades.format_stat("spawner_count", 1) == "+1", "spawner count reads flat")

func _check_resource()->void:
	_meta.reset_resource()
	_crystals.reset_resource()
	var _State:Dictionary = MetaUpgradeResource.State
	check(_meta.state(MetaUpgrades.ROOT) == _State.OWNED, "the root is owned")
	check(_meta.state("horde_root") == _State.OWNED, "the HORDE root is owned")
	check(_meta.state("frenzy_1") == _State.AVAILABLE, "a HORDE root child is available")
	check(_meta.state("vitality_1") == _State.AVAILABLE, "a root child is available")
	check(_meta.state("vitality_2") == _State.LOCKED, "a grandchild is locked")
	check(!_meta.buy("vitality_1"), "can't buy without crystals")
	_crystals.add(3)
	check(!_meta.buy("vitality_2"), "can't buy a locked node")
	check(_meta.buy("vitality_1") && _crystals.value == 2, "buying spends the cost")
	check(!_meta.buy("vitality_1"), "can't buy twice")
	check(_meta.state("vitality_2") == _State.AVAILABLE, "buying unlocks the next node")
	check(_meta.buy("vitality_2") && _crystals.value == 0, "buy the next node")
	check(_meta.state("survivor") == _State.AVAILABLE, "any one required node unlocks a node")
	check(is_equal_approx(_meta.stat("max_hp"), 20.0), "stats sum over owned nodes")
	check(FileAccess.file_exists(_meta.get_save_file_path()), "buying saves")

	var _loaded:MetaUpgradeResource = MetaUpgradeResource.new()
	_loaded.resource_name = _meta.resource_name
	_loaded.load_resource()
	check(_loaded.owned == _meta.owned, "owned nodes load back (%s)" % [_loaded.owned])

	var _collected:int = _crystals.collected_total
	_meta.refund_all()
	check(_crystals.value == 3 && _meta.owned.is_empty(), "refund gives every crystal back")
	check(_crystals.collected_total == _collected, "a refund doesn't count as collecting")

func _check_entry()->void:
	_meta.reset_resource()
	_crystals.reset_resource()
	var _title:Node = (load(SCENES + "title.tscn") as PackedScene).instantiate()
	add_child(_title)
	await _frames(2)
	var _entry:Control = _title.get_node("MarginContainer/Control/Body/TitleMenu/Upgrades")
	check(!_entry.visible, "title hides Upgrades before any crystal")
	check(_title.get_node("UpgradesComponent").scene_path == SCREEN, "Upgrades opens the meta screen")
	_crystals.add(1)
	check(_entry.visible, "title shows Upgrades once a crystal is picked up")
	_crystals.spend(1)
	check(_entry.visible, "Upgrades stays after the crystal is spent")
	_title.queue_free()

	for _path:String in [SCENES + "victory.tscn", TD + "scenes/ui/screens/game_over.tscn"]:
		var _screen:Node = (load(_path) as PackedScene).instantiate()
		add_child(_screen)
		await _frames(2)
		var _button:Control = _screen.get_node("MarginContainer/Control/Body/Menu/Upgrades")
		check(_button.visible, "%s shows Upgrades" % _path.get_file())
		_screen.queue_free()
	await _frames(2)

func _check_screen()->void:
	_meta.reset_resource()
	_crystals.reset_resource()
	var _screen:Node = (load(SCREEN) as PackedScene).instantiate()
	add_child(_screen)
	await _frames(3)
	var _buttons:Dictionary = _screen.buttons
	check(_buttons.size() == MetaUpgrades.nodes().size(), "a button per node")
	for _id:String in _buttons:
		var _button:MetaNodeButton = _buttons[_id]
		var _side:float = 28.0 if MetaUpgrades.is_keystone(_id) else 20.0
		check(_button.size == Vector2(_side, _side), "%s uses the %s frame" % [_id, "golden" if _side > 20.0 else "normal"])
	# Focus walks: every node is reached from the root by the four directions.
	var _seen:Dictionary = {MetaUpgrades.ROOT: true}
	var _queue:Array[String] = [MetaUpgrades.ROOT]
	while !_queue.is_empty():
		var _id:String = _queue.pop_front()
		for _side:Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var _next:String = _screen.neighbour(_id, _side)
			if !_seen.has(_next):
				_seen[_next] = true
				_queue.append(_next)
	for _id:String in _buttons:
		if MetaUpgrades.tree_of(_id) == MetaUpgrades.MAIN_TREE:
			check(_seen.has(_id), "focus reaches %s" % _id)
	check(_screen.neighbour(MetaUpgrades.ROOT, SIDE_TOP) == "vitality_1", "up from the root is Tough Skin I")
	check(_screen.neighbour(MetaUpgrades.ROOT, SIDE_RIGHT) == "sharpen_1", "right from the root is Sharpen I")
	check(_screen.neighbour("iron_heart", SIDE_TOP) == "iron_heart", "focus stays at the top end")
	for _id:String in _buttons:
		check(_buttons[_id].visible == (MetaUpgrades.tree_of(_id) == MetaUpgrades.MAIN_TREE), "the main tree shows only its own %s" % _id)

	# The sister tree: its nodes only, its own focus walk, the title follows.
	_screen.next_tree()
	check(_screen.tree == "horde" && _screen.title_label.text == "HORDE", "the tree button switches to HORDE")
	check(_screen.focused_id == "horde_root", "switching focuses the HORDE root")
	for _id:String in _buttons:
		check(_buttons[_id].visible == (MetaUpgrades.tree_of(_id) == "horde"), "HORDE shows only its own %s" % _id)
	_seen = {"horde_root": true}
	_queue = ["horde_root"]
	while !_queue.is_empty():
		var _id:String = _queue.pop_front()
		for _side:Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var _next:String = _screen.neighbour(_id, _side)
			check(MetaUpgrades.tree_of(_next) == "horde", "focus from %s stays in HORDE" % _id)
			if !_seen.has(_next):
				_seen[_next] = true
				_queue.append(_next)
	check(_seen.size() == MetaUpgrades.nodes_in("horde").size(), "focus reaches every HORDE node")
	_screen.next_tree()
	check(_screen.tree == "coop" && _screen.title_label.text == "CO-OP", "then the CO-OP tree")
	check(_screen.focused_id == "coop_root", "switching focuses the CO-OP root")
	for _id:String in ["shell_printer", "electrician_bay"]:
		check(MetaUpgrades.tree_of(_id) == "coop" && _buttons[_id].visible, "CO-OP shows %s" % _id)
	check(MetaUpgrades.effects("shell_printer").get("shell_printer", 0) == 1 && MetaUpgrades.effects("electrician_bay").get("guest_electricians", 0) == 1, "CO-OP nodes carry their flags")
	check(MetaUpgrades.describe("electrician_bay").find("{") < 0, "CO-OP texts have no unfilled stats")
	_screen.next_tree()
	check(_screen.tree == MetaUpgrades.MAIN_TREE && _screen.title_label.text == "UPGRADES", "and back to the main tree")

	_crystals.add(1)
	(_buttons["sharpen_1"] as MetaNodeButton).pressed.emit()
	check(_meta.is_owned("sharpen_1"), "pressing an affordable node buys it")
	check(_screen.crystal_label.text == "0", "the crystal counter follows")
	(_buttons["sharpen_2"] as MetaNodeButton).pressed.emit()
	check(!_meta.is_owned("sharpen_2"), "pressing an unaffordable node does nothing")
	_screen.queue_free()
	await _frames(2)

## A new run with Tough Skin I, Sharpen I, Swift Feet and Scavenger owned.
func _check_effects()->void:
	_meta.reset_resource()
	_meta.owned = ["vitality_1", "sharpen_1", "swift_1", "scavenger"]
	var _transition:SceneTransitionResource = load(TD + "resources/global_resources/scene_transition_resource.tres")
	_transition.next_scene_path = ""
	var _room:Node = (load(SCENES + "room_N00.tscn") as PackedScene).instantiate()
	add_child(_room)
	await _frames(5)
	var _player:Node = (load(TD + "resources/ReferenceNodeResources/player_reference.tres") as ReferenceNodeResource).node
	check(_player != null, "the run spawns a player")
	if _player != null:
		var _resources:ResourceNode = _player.get_node("ResourceNode")
		var _health:HealthResource = _resources.get_resource("health")
		check(is_equal_approx(_health.max_hp, 60.0) && is_equal_approx(_health.hp, 60.0), "max health 50 + 10 (%s/%s)" % [_health.hp, _health.max_hp])
		var _movement:ActorStatsResource = _resources.get_resource("movement")
		check(is_equal_approx(_movement.get_max_speed(), 60.0 * 1.08), "speed 60 x 1.08 (%s)" % _movement.get_max_speed())
		var _weapons:WeaponManager = _player.get_node("WeaponManager")
		check(is_equal_approx(_weapons.meta_damage_multiply, 1.1), "weapon damage x 1.1")
		if _weapons.default_weapon != null:
			check(is_equal_approx(_weapons.default_weapon.damage_data_resource.upgrade_multiply, 1.1), "fists get the damage bonus")
	check(LootItems.counter("coin").value == 10, "Scavenger starts the run with 10 coins")
	_room.queue_free()
	await _frames(2)
	_meta.reset_resource()

## Screenshot with a few nodes owned, crystals to spend and `focus` selected
## ("title" shoots the title menu instead).
func _shot(path:String, focus:String)->void:
	_meta.owned = ["vitality_1", "vitality_2", "sharpen_1", "swift_1", "scavenger", "pocket_meat"]
	_crystals.add(4)
	if focus == "title":
		add_child((load(SCENES + "title.tscn") as PackedScene).instantiate())
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(path)
		return
	var _screen:Node = (load(SCREEN) as PackedScene).instantiate()
	add_child(_screen)
	await _frames(3)
	_screen.buttons[focus].grab_focus()
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(path)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
