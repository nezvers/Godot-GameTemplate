## Takes a coin and pays out nothing, a meat chunk or a weapon pickup.
## Coins are the score, so every pull lowers it.
class_name SlotMachine
extends Interactable

enum Outcome {NOTHING, MEAT, WEAPON}

@export var score_resource:ScoreResource
@export var coin_cost:int = 1
@export var nothing_weight:float = 55.0
@export var meat_weight:float = 30.0
@export var weapon_weight:float = 15.0
@export var meat_instance:InstanceResource
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

## Weighted pick; `value` is a random number in [0, 1).
static func pick_outcome(weights:Array[float], value:float)->Outcome:
	var _total:float = 0.0
	for _weight:float in weights:
		_total += maxf(_weight, 0.0)
	if _total <= 0.0:
		return Outcome.NOTHING
	var _target:float = value * _total
	for i:int in weights.size():
		_target -= maxf(weights[i], 0.0)
		if _target < 0.0:
			return i as Outcome
	return (weights.size() - 1) as Outcome

func _can_use()->bool:
	return score_resource.can_spend(coin_cost)

func _use()->void:
	score_resource.spend(coin_cost)
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

func _pay_out()->void:
	busy = false
	var _outcome:Outcome = pick_outcome([nothing_weight, meat_weight, weapon_weight], randf())
	var _weapon:ItemResource = _pick_weapon() if _outcome == Outcome.WEAPON else null
	if _outcome == Outcome.WEAPON && _weapon == null:
		_outcome = Outcome.MEAT
	var _position:Vector2 = output_marker.global_position
	match _outcome:
		Outcome.NOTHING:
			deny()
		Outcome.MEAT:
			meat_instance.instance(func (inst:Node2D)->void: inst.global_position = _position)
			if sound_win != null:
				sound_win.play_managed()
		Outcome.WEAPON:
			item_pickup_instance.instance(func (inst:ItemPickup)->void:
				inst.item_resource = _weapon
				inst.global_position = _position
			)
			if sound_win != null:
				sound_win.play_managed()

func _pick_weapon()->ItemResource:
	var _pool:Array[ItemResource] = weapon_database.list.filter(
		func (item:ItemResource)->bool: return item != null && item.unlocked && item.type == ItemResource.ItemType.WEAPON
	)
	return _pool.pick_random() if !_pool.is_empty() else null

func _prompt_text()->String:
	return "Spin %dG" % coin_cost
