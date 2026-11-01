## Plays room_A02 headless: walks the player to each contraption and presses interact.
## Also checks the zen animation (and its texts) the ZenAnnouncer plays for each result.
##   Godot --headless --path . res://game/tests/contraption_play_check.tscn
extends Node

const TD:String = "res://addons/top_down/"

var failures:int = 0
var checks:int = 0
## [scene file, text args] of every zen scene the announcer added
var zen_played:Array[Array] = []

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	var _actions:ActionResource = load(TD + "resources/global_resources/action_resource.tres")
	_actions.reset_resource()
	var _score:ScoreResource = load(TD + "resources/global_resources/score_resource.tres")
	var _meat:ScoreResource = load(TD + "resources/global_resources/meat_resource.tres")
	var _slime:ScoreResource = load(TD + "resources/global_resources/slime_resource.tres")
	var _upgrades:WeaponUpgradeResource = load(TD + "resources/global_resources/weapon_upgrade_resource.tres")
	var _inventory:ItemCollectionResource = load(TD + "resources/ItemCollectionResource/weapon_inventory.tres")
	var _database:ItemCollectionResource = load(TD + "resources/ItemCollectionResource/weapon_database.tres")
	for _resource:Resource in [_score, _meat, _slime, _upgrades]:
		_resource.reset_resource()
	_inventory.list.clear()
	_inventory.append(_database.list[0])
	var _gun_path:String = _database.list[0].scene_path

	var _room:Node = (load("res://game/scenes/room_A02.tscn") as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)
	var _player_reference:ReferenceNodeResource = load(TD + "resources/ReferenceNodeResources/player_reference.tres")
	var _player:Node2D = _player_reference.node
	check(_player != null, "player spawned")
	if _player == null:
		_finish()
		return
	var _announcer:ZenAnnouncer = _room.get_node("ZenAnnouncer")
	_announcer.add_to_group(&"zen_announcer_test")
	_announcer.child_entered_tree.connect(func (node:Node)->void:
		zen_played.append([node.scene_file_path.get_file(), Array(node.text_args)])
	)
	var _ysort:Node = _room.get_node("WallLayer_Ysorted")
	var _grinder:MeatGrinder = _ysort.get_node("MeatGrinder")
	var _bench:SlimeWorkbench = _ysort.get_node("SlimeWorkbench")
	var _slot:SlotMachine = _ysort.get_node("SlotMachine")

	# Grinder: denied without meat, then 3 meat -> health pickup
	await _stand_at(_player, _grinder)
	check(_grinder.prompt_label.visible, "grinder prompt shows in range")
	check(!_bench.prompt_label.visible, "only the nearest prompt shows")
	await _press_interact()
	check(_meat.value == 0, "grinder denied without meat")
	_meat.add(3)
	await _frames(20)
	var _health_before:int = _count_named(_ysort, "HealthPickup")
	await _press_interact()
	check(_meat.value == 0 && _meat.collected_total == 3, "grinder took 3 meat")
	await get_tree().create_timer(0.8).timeout
	check(_count_named(_ysort, "HealthPickup") == _health_before + 1, "grinder spawned a health pickup")
	check_zen("zs_meat_grinder.tscn", ["3", "10"], "grinder zen: 3 meat, +10 health")

	# Workbench: hidden until slime, then upgrades the held gun
	check(!_bench.visible, "bench hidden without slime")
	_slime.add(2)
	check(_bench.visible, "bench visible after slime")
	await _frames(2)
	check_zen("zs_workbench_unlocked.tscn", ["PISTOL"], "bench unlocked zen names the held gun")
	await _stand_at(_player, _bench)
	check(_bench.prompt_label.visible, "bench prompt shows in range")
	await _press_interact()
	check(_slime.value == 0 && _upgrades.get_level(_gun_path) == 1, "bench upgraded the gun")
	var _manager:WeaponManager = _player.get_node("WeaponManager")
	check(is_equal_approx(_manager.current_weapon.damage_data_resource.upgrade_multiply, 1.2), "held gun damage x1.2")
	check_zen("zs_weapon_upgrade.tscn", ["PISTOL", "1", "1.2", "1.1"], "upgrade zen: level, damage, fire rate")

	# Slot machine: each pull costs a coin, payout appears after the spin
	_score.add(5)
	await _stand_at(_player, _slot)
	await _press_interact()
	check(_score.value == 4, "slot took one coin")
	await _press_interact()
	check(_score.value == 4, "slot ignores presses while spinning")
	await get_tree().create_timer(1.3).timeout
	check(!_slot.busy, "slot finished spinning")

	# Each payout plays its own slot zen
	var _cases:Array = [
		[{"drop": "nothing", "weight": 1}, "zs_slot_bust.tscn", ["1"]],
		[{"drop": "meat", "amount": 3, "weight": 1}, "zs_slot_meat.tscn", ["3"]],
		[{"drop": "coin", "amount": 5, "weight": 1}, "zs_slot_coins.tscn", ["5"]],
		[{"drop": "weapon", "weight": 1}, "zs_slot_jackpot.tscn", []],
	]
	var _dropped_weapons:Array[ItemResource] = []
	_slot.paid_out.connect(func (_drop:String, _amount:int, weapon:ItemResource)->void: _dropped_weapons.append(weapon))
	for _case:Array in _cases:
		_slot.payouts = [_case[0]]
		zen_played.clear()
		await _press_interact()
		await get_tree().create_timer(1.3).timeout
		# the jackpot names whichever weapon the random pick dropped
		var _args:Array = _case[2] if _case[0].drop != "weapon" else [_announcer.weapon_name(_dropped_weapons.back())]
		check(_case[0].drop != "weapon" || _dropped_weapons.back() != null, "slot dropped a weapon")
		check_zen(_case[1], _args, "slot %s zen" % _case[0].drop)

	_finish()

## The latest zen scene the announcer played or queued was `file` with these texts.
## Back-to-back results wait in its queue until the one before has finished.
func check_zen(file:String, args:Array, label:String)->void:
	var _announcer:ZenAnnouncer = get_tree().get_first_node_in_group(&"zen_announcer_test")
	var _last:Array = zen_played.back() if !zen_played.is_empty() else ["none", []]
	if _announcer != null && !_announcer._queue.is_empty():
		var _entry:Array = _announcer._queue.back()
		_last = [(_entry[0] as PackedScene).resource_path.get_file(), Array(_entry[1]).map(func (v:Variant)->String: return str(v))]
	check(_last[0] == file && _last[1] == args, "%s (got %s %s)" % [label, _last[0], _last[1]])

func _finish()->void:
	print("contraption_play_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame

func _stand_at(player:Node2D, target:Node2D)->void:
	player.global_position = target.global_position + Vector2(0, 12)
	await _frames(8)

func _press_interact()->void:
	var _event:InputEventAction = InputEventAction.new()
	_event.action = &"interact"
	_event.pressed = true
	Input.parse_input_event(_event)
	await _frames(2)
	_event = InputEventAction.new()
	_event.action = &"interact"
	_event.pressed = false
	Input.parse_input_event(_event)
	await _frames(20)

func _count_named(parent:Node, prefix:String)->int:
	var _count:int = 0
	for _child:Node in parent.get_children():
		if _child.name.begins_with(prefix) && _child.is_inside_tree() && _child.visible:
			_count += 1
	return _count
