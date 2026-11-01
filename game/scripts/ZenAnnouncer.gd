## Plays the Zen Animator HUD moments (res://zen/) over the room: wave start,
## boss wave, wave cleared, section ("room") cleared, weapon pickup cards and
## the contraptions' results (slot machine, meat grinder, slime workbench).
## The scenes are exported one-shots on a transparent 480x270 canvas; they are
## queued so back-to-back moments (wave cleared -> next wave) don't overlap.
## Never edit res://zen/ - a re-export replaces it; wire new scenes here.
class_name ZenAnnouncer
extends CanvasLayer

@export var wave_start_scene:PackedScene
@export var wave_cleared_scene:PackedScene
@export var boss_wave_scene:PackedScene
## Last wave of a section: "WAVE %1 COMPLETED WITH %2 ROOMS LEFT".
@export var room_cleared_scene:PackedScene

## Player's weapon inventory; a newly added weapon shows its card.
@export var weapon_inventory:ItemCollectionResource
## Weapon scene_path -> zen card scene.
@export var weapon_cards:Dictionary[String, PackedScene]
## Weapon scene_path -> name shown in zen texts, matching the cards; others use the item name.
@export var weapon_names:Dictionary[String, String]

@export_group("Contraptions")
## "%1 DROPPED": a weapon from the slot machine.
@export var slot_jackpot_scene:PackedScene
## "+%1 MEAT"
@export var slot_meat_scene:PackedScene
## "+%1 COINS"
@export var slot_coins_scene:PackedScene
## "-%1 COIN": the pull paid out nothing.
@export var slot_bust_scene:PackedScene
## "%1 MEAT GROUND UP", "+%2 HEALTH" (hit points healed).
@export var meat_grinder_scene:PackedScene
## "%1 LV %2", "DAMAGE x%3   FIRE RATE x%4"
@export var weapon_upgrade_scene:PackedScene
## "UPGRADE YOUR %1 WITH SLIME"
@export var workbench_unlocked_scene:PackedScene
@export_group("")

## Seconds a scene holds at a pause marker before it continues on its own.
@export var hold_time:float = 1.0

var _queue:Array[Array] = []
var _playing:bool
var _known_weapons:Array[String]
var _aggregator:ArenaSectionAggregator

func _ready()->void:
	_aggregator = get_tree().get_first_node_in_group(&"arena_aggregator")
	if _aggregator != null:
		_aggregator.wave_announced.connect(_on_wave_announced)
		_aggregator.wave_finished.connect(_on_wave_finished)
	if weapon_inventory != null:
		_known_weapons = _weapon_paths()
		weapon_inventory.updated.connect(_on_inventory_updated)
	## Contraptions join their group in their own _ready, after this one runs.
	_connect_contraptions.call_deferred()

func _on_wave_announced(wave_number:int, enemies:int, is_boss:bool, boss_name:String)->void:
	var _scene:PackedScene = boss_wave_scene if is_boss else wave_start_scene
	var _args:Array = [boss_name if !boss_name.is_empty() else "BOSS"] if is_boss else [wave_number, enemies]
	## The wave spawns only once its announcement has played.
	if _scene != null && _aggregator != null:
		_aggregator.hold_spawning()
		play(_scene, _args, _aggregator.release_spawning)
	else:
		play(_scene, _args)

func _on_wave_finished(wave_number:int, waves_left:int, section_cleared:bool, sections_left:int)->void:
	if section_cleared:
		play(room_cleared_scene, [wave_number, sections_left])
	else:
		play(wave_cleared_scene, [wave_number, waves_left])

func _on_inventory_updated()->void:
	var _paths:Array[String] = _weapon_paths()
	for _path:String in _paths:
		if !_known_weapons.has(_path) && weapon_cards.has(_path):
			## Empty args: the card's own sample texts are the weapon name/description.
			play(weapon_cards[_path], [])
	_known_weapons = _paths

func _connect_contraptions()->void:
	for _node:Node in get_tree().get_nodes_in_group(Interactable.ALL_GROUP):
		if _node is SlotMachine:
			_node.paid_out.connect(_on_slot_paid_out.bind(_node))
		elif _node is MeatGrinder:
			_node.ground.connect(_on_meat_ground)
		elif _node is SlimeWorkbench:
			_node.unlocked.connect(_on_workbench_unlocked)
			_node.upgraded.connect(_on_weapon_upgraded.bind(_node))

func _on_slot_paid_out(drop:String, amount:int, weapon:ItemResource, machine:SlotMachine)->void:
	match drop:
		"nothing":
			play(slot_bust_scene, [_cost_amount(machine.cost, "coin")])
		"weapon":
			play(slot_jackpot_scene, [weapon_name(weapon)])
		"meat":
			play(slot_meat_scene, [amount])
		"coin":
			play(slot_coins_scene, [amount])

func _on_meat_ground(cost:Array, rewards:Array)->void:
	var _heal:int = 0
	for _reward:Dictionary in rewards:
		if _reward.get("drop", "") == "health":
			_heal += int(_reward.get("amount", 1)) * int(Balance.value("pickups.health.heal", 10))
	play(meat_grinder_scene, [_cost_amount(cost, "meat"), _heal])

func _on_workbench_unlocked(item:ItemResource)->void:
	play(workbench_unlocked_scene, [weapon_name(item)])

func _on_weapon_upgraded(item:ItemResource, level:int, bench:SlimeWorkbench)->void:
	var _upgrade:WeaponUpgradeResource = bench.weapon_upgrade_resource
	var _fire_rate:float = 1.0 / _upgrade.interval_multiplier(item.scene_path)
	play(weapon_upgrade_scene, [weapon_name(item), level, _multiplier_text(_upgrade.damage_multiplier(item.scene_path)), _multiplier_text(_fire_rate)])

## Display name for zen texts; "WEAPON" when there is none.
func weapon_name(item:ItemResource)->String:
	if item == null:
		return "WEAPON"
	return weapon_names.get(item.scene_path, item.resource_name.to_upper())

static func _cost_amount(cost:Array, id:String)->int:
	var _total:int = 0
	for _entry:Dictionary in cost:
		if _entry.get("item", "") == id:
			_total += int(_entry.get("amount", 1))
	return _total

## 1.2 -> "1.2", 1.111 -> "1.1"
static func _multiplier_text(value:float)->String:
	return "%.1f" % value

func _weapon_paths()->Array[String]:
	var _paths:Array[String] = []
	for _item:ItemResource in weapon_inventory.list:
		if _item != null:
			_paths.append(_item.scene_path)
	return _paths

## Queue a zen scene; args fill its %1, %2... text args (empty keeps the samples).
## on_done runs once the scene has finished playing.
func play(scene:PackedScene, args:Array, on_done:Callable = Callable())->void:
	if scene == null:
		return
	_queue.append([scene, args, on_done])
	if !_playing:
		_play_next()

func _play_next()->void:
	if _queue.is_empty():
		_playing = false
		return
	_playing = true
	var _entry:Array = _queue.pop_front()
	var _anim:Node2D = (_entry[0] as PackedScene).instantiate()
	## Gameplay keeps the mouse; pause markers continue on a timer instead.
	_anim.click_to_continue = false
	_anim.pointer_input = false
	if !(_entry[1] as Array).is_empty():
		_anim.set_text_args(_entry[1])
	_anim.paused.connect(_on_anim_paused.bind(_anim))
	_anim.finished.connect(_on_anim_finished.bind(_anim, _entry[2]), CONNECT_ONE_SHOT)
	## Stretch is keep_height: centre the 480-wide canvas in a wider viewport.
	var _width:float = get_viewport().get_visible_rect().size.x
	_anim.position.x = roundf((_width - _anim.design_size.x) * 0.5)
	add_child(_anim)

func _on_anim_paused(_index:int, anim:Node2D)->void:
	## A tween (not a SceneTree timer) so it freezes with the room on pause.
	anim.create_tween().tween_callback(anim.resume).set_delay(hold_time)

func _on_anim_finished(anim:Node2D, on_done:Callable)->void:
	anim.queue_free()
	if on_done.is_valid():
		on_done.call()
	_play_next()
