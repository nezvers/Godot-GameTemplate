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
	check(is_equal_approx(_upgrades.damage_multiplier(_path), 1.0), "level 0 damage x1")
	for i:int in _upgrades.max_level:
		check(_upgrades.upgrade(_path), "upgrade %d" % (i + 1))
	check(!_upgrades.upgrade(_path), "upgrade past max refused")
	check(is_equal_approx(_upgrades.damage_multiplier(_path), 1.6), "level 3 damage x1.6")
	check(is_equal_approx(_upgrades.interval_multiplier(_path), 0.7), "level 3 interval x0.7")

	# WeaponManager applies the multipliers without compounding
	var _manager:WeaponManager = WeaponManager.new()
	_manager.weapon_upgrade_resource = _upgrades
	var _weapon:Weapon = (load(_path) as PackedScene).instantiate()
	_weapon.damage_data_resource = _weapon.damage_data_resource.duplicate()
	var _interval_node:Node = _weapon.get_node("WeaponTrigger/ProjectileInterval")
	var _base:float = _interval_node.interval
	_manager._apply_upgrade(_weapon, _path)
	_manager._apply_upgrade(_weapon, _path)
	check(is_equal_approx(_interval_node.interval, _base * 0.7), "interval scaled once")
	check(is_equal_approx(_weapon.damage_data_resource.upgrade_multiply, 1.6), "damage multiply set")
	check(is_equal_approx(_weapon.damage_data_resource.new_generation().upgrade_multiply, 1.6), "generation carries multiply")
	_weapon.free()
	_manager.free()

func _check_slot_odds()->void:
	var _weights:Array[float] = [55.0, 30.0, 15.0]
	var _counts:Array[int] = [0, 0, 0]
	var _rolls:int = 10000
	for i:int in _rolls:
		_counts[SlotMachine.pick_outcome(_weights, randf())] += 1
	print("slot outcomes /10000: nothing %d, meat %d, weapon %d" % _counts)
	check(absf(_counts[0] / float(_rolls) - 0.55) < 0.03, "nothing ~55%")
	check(absf(_counts[1] / float(_rolls) - 0.30) < 0.03, "meat ~30%")
	check(absf(_counts[2] / float(_rolls) - 0.15) < 0.03, "weapon ~15%")
	check(SlotMachine.pick_outcome(_weights, 0.0) == SlotMachine.Outcome.NOTHING, "low edge")
	check(SlotMachine.pick_outcome(_weights, 0.9999) == SlotMachine.Outcome.WEAPON, "high edge")
	check(SlotMachine.pick_outcome([0.0, 0.0, 0.0] as Array[float], 0.5) == SlotMachine.Outcome.NOTHING, "zero weights")

func _check_scenes()->void:
	for _name:String in ["meat", "slime", "boss_crystal"]:
		var _instance:InstanceResource = load(TD + "resources/InstanceResources/pickups/%s_instance_resource.tres" % _name)
		check(_instance != null && ResourceLoader.exists(_instance.scene_path), "%s instance resource" % _name)
		var _scene:PackedScene = load(TD + "scenes/pickups/%s_pickup.tscn" % _name)
		var _node:Node = _scene.instantiate() if _scene != null else null
		check(_node != null && _node.get_node("CollectingPoint").point_resource != null, "%s pickup scene" % _name)
		if _node != null:
			_node.free()
	for _boss:String in ["boss_big_jelly", "broodmother_boss", "giant_zombie_boss", "plague_mother_boss"]:
		var _node:Node = (load(TD + "scenes/actors/%s.tscn" % _boss) as PackedScene).instantiate()
		var _drop:ItemDrop = _node.get_node_or_null("CrystalDrop")
		check(_drop != null && _drop.drop_instance_resources.size() == 1 && _drop.drop_instance_resources[0].scene_path.ends_with("boss_crystal_pickup.tscn"), "%s crystal drop" % _boss)
		check(Balance.find(_node, "ItemDrop") == _node.get_node("ItemDrop"), "%s ItemDrop selector still hits the health drop" % _boss)
		_node.free()
	var _manager:Node = (load(TD + "scenes/arena/enemy_manager.tscn") as PackedScene).instantiate()
	var _drops:DropManager = _manager.get_node("DropManager")
	check(_drops.meat_instance != null && _drops.slime_instance != null, "drop manager loot instances")
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

	check(_grinder.meat_cost == int(Balance.value("contraptions.meat_grinder.meat_cost")), "grinder cost from balance")
	check(_slot.weapon_weight == float(Balance.value("contraptions.slot_machine.weapon_weight")), "slot weights from balance")
	check(_bench.weapon_upgrade_resource.max_level == int(Balance.value("contraptions.slime_workbench.max_level")), "bench pushes max level")

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
	check(_slot._pick_weapon() != null && _slot._pick_weapon().unlocked, "slot weapon pool")

	_grinder.queue_free()
	_bench.queue_free()
	_slot.queue_free()
	_slime.reset_resource()
	_meat.reset_resource()
	await get_tree().process_frame
