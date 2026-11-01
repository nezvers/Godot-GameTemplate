## Headless checks for loot pickups, contraptions and weapon upgrades.
## Run as the main scene so autoloads behave as in game:
##   Godot --headless --path . res://game/tests/pickup_checks.tscn
extends Node

const TD:String = "res://addons/top_down/"

var failures:int = 0
var checks:int = 0

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	_check_score_resource()
	_check_upgrades()
	_check_slot_odds()
	_check_scenes()
	await get_tree().process_frame
	await _check_contraptions_in_tree()
	print("pickup_checks: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check_score_resource()->void:
	var _counter:ScoreResource = ScoreResource.new()
	_counter.add(3)
	_counter.add_point()
	check(_counter.value == 4 && _counter.collected_total == 4, "add counts value and total")
	check(!_counter.spend(5) && _counter.value == 4, "overspend refused")
	check(_counter.spend(3) && _counter.value == 1 && _counter.collected_total == 4, "spend lowers value only")
	_counter.reset_resource()
	check(_counter.value == 0 && _counter.collected_total == 0, "reset")

func _check_upgrades()->void:
	var _upgrades:WeaponUpgradeResource = WeaponUpgradeResource.new()
	var _path:String = TD + "scenes/weapons/gun.tscn"
	var _table:Array = Balance.value("weapons.gun.upgrades", [])
	check(_table.size() == 3 && _upgrades.max_level(_path) == 3, "gun has 3 upgrade levels from balance")
	check(is_equal_approx(_upgrades.damage_multiplier(_path), 1.0), "level 0 damage x1")
	check(_upgrades.next_upgrade(_path).cost == _table[0].cost, "next cost is level 1 cost")
	var _items:Array = _table.map(func (level:Dictionary)->Array: return level.cost.map(func (entry:Dictionary)->String: return entry.item))
	check(_items[1].has("meat") && _items[1].has("slime"), "a level costs slime + meat")
	check(_items[2].has("boss_crystal") && _items[2].has("slime"), "last level costs slime + boss crystal")
	for i:int in _table.size():
		check(_upgrades.upgrade(_path), "upgrade %d" % (i + 1))
	check(!_upgrades.upgrade(_path) && _upgrades.next_upgrade(_path).is_empty(), "upgrade past max refused")
	check(is_equal_approx(_upgrades.damage_multiplier(_path), float(_table[2].damage)), "max level damage from balance")
	check(is_equal_approx(_upgrades.interval_multiplier(_path), float(_table[2].interval)), "max level interval from balance")
	for _id:String in ["gun", "shotgun", "assault_rifle", "sword"]:
		var _price:Array = Balance.value("weapons.%s.price" % _id, [])
		check(!_price.is_empty() && _price[0].item == "coin", "%s has a coin price" % _id)
		check(float(Balance.value("weapons.%s.jackpot_weight" % _id, 0)) > 0.0, "%s has a jackpot weight" % _id)

	# WeaponManager applies the multipliers without compounding
	var _manager:WeaponManager = WeaponManager.new()
	_manager.weapon_upgrade_resource = _upgrades
	var _weapon:Weapon = (load(_path) as PackedScene).instantiate()
	_weapon.damage_data_resource = _weapon.damage_data_resource.duplicate()
	var _interval_node:Node = _weapon.get_node("WeaponTrigger/ProjectileInterval")
	var _base:float = _interval_node.interval
	_manager._apply_upgrade(_weapon, _path)
	_manager._apply_upgrade(_weapon, _path)
	check(is_equal_approx(_interval_node.interval, _base * float(_table[2].interval)), "interval scaled once")
	check(is_equal_approx(_weapon.damage_data_resource.upgrade_multiply, float(_table[2].damage)), "damage multiply set")
	check(is_equal_approx(_weapon.damage_data_resource.new_generation().upgrade_multiply, float(_table[2].damage)), "generation carries multiply")
	_weapon.free()
	_manager.free()

	# Costs pay from several counters at once, or not at all
	var _slime:ScoreResource = LootItems.counter("slime")
	var _meat:ScoreResource = LootItems.counter("meat")
	_slime.reset_resource()
	_meat.reset_resource()
	var _cost:Array = [{"item": "slime", "amount": 2}, {"item": "meat", "amount": 3}]
	_slime.add(2)
	_meat.add(2)
	check(!LootItems.pay(_cost) && _slime.value == 2 && _meat.value == 2, "short cost pays nothing")
	_meat.add(1)
	check(LootItems.describe(_cost) == "2/2 slime + 3/3 meat", "cost description")
	check(LootItems.pay(_cost) && _slime.value == 0 && _meat.value == 0, "full cost pays every item")
	_slime.reset_resource()
	_meat.reset_resource()

func _check_slot_odds()->void:
	var _weights:Array[float] = [55.0, 30.0, 15.0]
	var _counts:Array[int] = [0, 0, 0]
	var _rolls:int = 10000
	for i:int in _rolls:
		_counts[SlotMachine.pick_weighted(_weights, randf())] += 1
	print("weighted picks /10000: %d, %d, %d" % _counts)
	check(absf(_counts[0] / float(_rolls) - 0.55) < 0.03, "first ~55%")
	check(absf(_counts[1] / float(_rolls) - 0.30) < 0.03, "second ~30%")
	check(absf(_counts[2] / float(_rolls) - 0.15) < 0.03, "third ~15%")
	check(SlotMachine.pick_weighted(_weights, 0.0) == 0, "low edge")
	check(SlotMachine.pick_weighted(_weights, 0.9999) == 2, "high edge")
	check(SlotMachine.pick_weighted([0.0, 0.0] as Array[float], 0.5) == -1, "zero weights")
	check(LootItems.roll_count(1.5, 0.4) == 2 && LootItems.roll_count(1.5, 0.6) == 1, "chance above 1 rolls extra")
	check(LootItems.roll_count(0.0, 0.0) == 0 && LootItems.roll_count(1.0, 0.99) == 1, "roll edges")

func _check_scenes()->void:
	for _name:String in ["meat", "slime", "boss_crystal"]:
		var _instance:InstanceResource = load(TD + "resources/InstanceResources/pickups/%s_instance_resource.tres" % _name)
		check(_instance != null && ResourceLoader.exists(_instance.scene_path), "%s instance resource" % _name)
		var _scene:PackedScene = load(TD + "scenes/pickups/%s_pickup.tscn" % _name)
		var _node:Node = _scene.instantiate() if _scene != null else null
		check(_node != null && _node.get_node("CollectingPoint").point_resource != null, "%s pickup scene" % _name)
		if _node != null:
			_node.free()
	for _id:String in ["zombie", "slime", "skitter_spider"]:
		var _drops:Dictionary = DropManager.enemy_drops(Balance.value("enemies.%s.scene" % _id))
		check(_drops.has("coin") && _drops.has("meat") && _drops.has("slime"), "%s drop table" % _id)
	for _id:String in ["big_jelly", "giant_zombie", "broodmother", "plague_mother"]:
		var _drops:Dictionary = DropManager.enemy_drops(Balance.value("bosses.%s.scene" % _id))
		check(float(_drops.get("boss_crystal", 0)) >= 1.0, "%s always drops a crystal" % _id)
	for _id:String in Balance.value("enemies", {}).keys() + Balance.value("bosses", {}).keys():
		var _entry:Dictionary = Balance.value("enemies.%s" % _id, Balance.value("bosses.%s" % _id, {}))
		for _item:String in _entry.get("drops", {}):
			check(LootItems.can_spawn(_item), "%s drop '%s' has a pickup" % [_id, _item])
	var _manager:Node = (load(TD + "scenes/arena/enemy_manager.tscn") as PackedScene).instantiate()
	check(is_equal_approx(_manager.get_node("DropManager").loot_multiplier, 1.0), "drop manager default multiplier")
	_manager.free()
	check(InputMap.has_action(&"interact") || load(TD + "resources/global_resources/action_resource.tres").interact_kb != null, "interact action defined")

func _check_contraptions_in_tree()->void:
	var _slime:ScoreResource = load(TD + "resources/global_resources/slime_resource.tres")
	var _meat:ScoreResource = load(TD + "resources/global_resources/meat_resource.tres")
	_slime.reset_resource()
	_meat.reset_resource()

	var _grinder:MeatGrinder = (load(TD + "scenes/interactables/meat_grinder.tscn") as PackedScene).instantiate()
	var _bench:SlimeWorkbench = (load(TD + "scenes/interactables/slime_workbench.tscn") as PackedScene).instantiate()
	var _slot:SlotMachine = (load(TD + "scenes/interactables/slot_machine.tscn") as PackedScene).instantiate()
	add_child(_grinder)
	add_child(_bench)
	add_child(_slot)
	await get_tree().process_frame

	check(_grinder.cost == Balance.value("contraptions.meat_grinder.cost"), "grinder cost from balance")
	check(_slot.payouts.size() == Balance.value("contraptions.slot_machine.payouts").size(), "slot payouts from balance")
	check(_slot.cost == Balance.value("contraptions.slot_machine.cost"), "slot cost from balance")
	var _drops_seen:Dictionary = {}
	for i:int in 2000:
		_drops_seen[_slot.roll_payout(randf()).get("drop", "?")] = true
	check(_drops_seen.has("nothing") && _drops_seen.has("meat") && _drops_seen.has("coin") && _drops_seen.has("weapon"), "every payout kind rolls")
	var _weapon_counts:Dictionary = {}
	for i:int in 4000:
		var _weapon:ItemResource = _slot.pick_weapon(randf())
		_weapon_counts[_weapon.resource_name] = _weapon_counts.get(_weapon.resource_name, 0) + 1
	print("jackpot weapons /4000: ", _weapon_counts)
	check(_weapon_counts.get("Gun", 0) > _weapon_counts.get("Assault Riffle", 0), "jackpot weights favour the gun")

	check(!_bench.visible && _bench.process_mode == Node.PROCESS_MODE_DISABLED, "bench hidden before any slime")
	_slime.add(1)
	check(_bench.visible && _bench.process_mode == Node.PROCESS_MODE_INHERIT, "bench shows after first slime")
	_slime.spend(1)
	check(_bench.visible, "bench stays after spending")

	check(!_grinder._can_use(), "grinder denied without meat")
	_meat.add(3)
	check(_grinder._can_use(), "grinder usable with 3 meat")
	_grinder.try_use()
	check(_meat.value == 0 && _grinder.busy, "grinder spends meat and plays")

	_grinder.queue_free()
	_bench.queue_free()
	_slot.queue_free()
	_slime.reset_resource()
	_meat.reset_resource()
	await get_tree().process_frame
