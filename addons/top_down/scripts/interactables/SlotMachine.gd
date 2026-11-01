## Takes coins and pays out one weighted entry of `payouts`.
## Coins are the score, so every pull lowers it.
class_name SlotMachine
extends Interactable

## [{"item": id, "amount": n}] per pull (contraptions.slot_machine.cost).
@export var cost:Array[Dictionary] = [{"item": "coin", "amount": 1}]
## [{"drop": id, "amount": n, "weight": w}] (contraptions.slot_machine.payouts).
## drop is "nothing", "weapon" (picked by weapons.<id>.jackpot_weight) or a LootItems pickup id.
@export var payouts:Array[Dictionary] = [
	{"drop": "nothing", "weight": 55},
	{"drop": "meat", "amount": 1, "weight": 30},
	{"drop": "weapon", "weight": 15},
]
@export var item_pickup_instance:InstanceResource
## Unlocked weapons from here are the prize pool.
@export var weapon_database:ItemCollectionResource
@export var output_marker:Marker2D
## Frame 0 idle, 1 lever pulled, 2 reels spinning.
@export var sprite:Sprite2D
@export var sound_spin:SoundResource
@export var sound_win:SoundResource

const SPIN_TIME:float = 0.8
const SPIN_FRAME_TIME:float = 0.08

## Weighted pick of an index; `value` is a random number in [0, 1). -1 when nothing has weight.
static func pick_weighted(weights:Array[float], value:float)->int:
	var _total:float = 0.0
	for _weight:float in weights:
		_total += maxf(_weight, 0.0)
	if _total <= 0.0:
		return -1
	var _target:float = value * _total
	for i:int in weights.size():
		_target -= maxf(weights[i], 0.0)
		if _target < 0.0:
			return i
	return weights.size() - 1

func _can_use()->bool:
	return LootItems.can_afford(cost)

func _use()->void:
	LootItems.pay(cost)
	busy = true
	var _tween:Tween = create_tween()
	_tween.tween_callback(sprite.set_frame.bind(1))
	_tween.tween_interval(0.12)
	var _steps:int = int(SPIN_TIME / SPIN_FRAME_TIME)
	for i:int in _steps:
		_tween.tween_callback(sprite.set_frame.bind(2 if i % 2 == 0 else 1))
		if i % 3 == 0 && sound_spin != null:
			_tween.tween_callback(sound_spin.play_managed)
		_tween.tween_interval(SPIN_FRAME_TIME)
	_tween.tween_callback(sprite.set_frame.bind(0))
	_tween.tween_callback(_pay_out)

func roll_payout(value:float)->Dictionary:
	var _weights:Array[float] = []
	for _payout:Dictionary in payouts:
		_weights.append(float(_payout.get("weight", 0.0)))
	var _index:int = pick_weighted(_weights, value)
	return payouts[_index] if _index >= 0 else {}

func _pay_out()->void:
	busy = false
	var _payout:Dictionary = roll_payout(randf())
	var _drop:String = _payout.get("drop", "nothing")
	var _amount:int = int(_payout.get("amount", 1))
	var _position:Vector2 = output_marker.global_position
	if _drop == "weapon":
		var _weapon:ItemResource = pick_weapon(randf())
		if _weapon == null:
			deny()
			return
		item_pickup_instance.instance(func (inst:ItemPickup)->void:
			inst.item_resource = _weapon
			inst.global_position = _position
		)
	elif LootItems.can_spawn(_drop):
		LootItems.spawn(_drop, _amount, _position)
	else:
		deny()
		return
	if sound_win != null:
		sound_win.play_managed()

## Unlocked weapon picked by its balance jackpot_weight; weapons without one never drop.
func pick_weapon(value:float)->ItemResource:
	var _pool:Array[ItemResource] = []
	var _weights:Array[float] = []
	for _item:ItemResource in weapon_database.list:
		if _item == null || !_item.unlocked || _item.type != ItemResource.ItemType.WEAPON:
			continue
		var _found:Array = Balance.entry_for_scene(_item.scene_path)
		var _weight:float = float(_found[2].get("jackpot_weight", 0.0)) if !_found.is_empty() else 0.0
		if _weight <= 0.0:
			continue
		_pool.append(_item)
		_weights.append(_weight)
	var _index:int = pick_weighted(_weights, value)
	return _pool[_index] if _index >= 0 else null

func _prompt_text()->String:
	return "Spin %s" % LootItems.describe(cost)
