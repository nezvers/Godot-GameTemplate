## Plays room_A02 headless: walks the player to each contraption and presses interact.
##   Godot --headless --path . res://game/tests/contraption_play_check.tscn
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

	# Workbench: hidden until slime, then upgrades the held gun
	check(!_bench.visible, "bench hidden without slime")
	_slime.add(2)
	check(_bench.visible, "bench visible after slime")
	await _stand_at(_player, _bench)
	check(_bench.prompt_label.visible, "bench prompt shows in range")
	await _press_interact()
	check(_slime.value == 0 && _upgrades.get_level(_gun_path) == 1, "bench upgraded the gun")
	var _manager:WeaponManager = _player.get_node("WeaponManager")
	check(is_equal_approx(_manager.current_weapon.damage_data_resource.upgrade_multiply, 1.2), "held gun damage x1.2")

	# Slot machine: each pull costs a coin, payout appears after the spin
	_score.add(5)
	await _stand_at(_player, _slot)
	await _press_interact()
	check(_score.value == 4, "slot took one coin")
	await _press_interact()
	check(_score.value == 4, "slot ignores presses while spinning")
	await get_tree().create_timer(1.3).timeout
	check(!_slot.busy, "slot finished spinning")

	_finish()

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
