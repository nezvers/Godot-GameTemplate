## Turns meat chunks into healing.
class_name MeatGrinder
extends Interactable

## The cost was paid and the rewards spawned.
signal ground(cost:Array, rewards:Array)

## [{"item": id, "amount": n}], paid from the loot counters (contraptions.meat_grinder.cost).
@export var cost:Array[Dictionary] = [{"item": "meat", "amount": 3}]
## [{"drop": id, "amount": n}] spawned at the output (contraptions.meat_grinder.rewards).
@export var rewards:Array[Dictionary] = [{"drop": "health", "amount": 1}]
@export var output_marker:Marker2D
## Frame 0 idle, frames 1-3 the crank turning.
@export var sprite:Sprite2D

const CRANK_FRAMES:Array[int] = [1, 2, 3, 1, 2, 3, 0]
const FRAME_TIME:float = 0.07

func _can_use()->bool:
	return LootItems.can_afford(cost)

func _use()->void:
	LootItems.pay(cost)
	busy = true
	var _tween:Tween = create_tween()
	for _frame:int in CRANK_FRAMES:
		_tween.tween_callback(sprite.set_frame.bind(_frame))
		_tween.tween_interval(FRAME_TIME)
	_tween.tween_callback(_finish)

func _finish()->void:
	busy = false
	for _reward:Dictionary in rewards:
		LootItems.spawn(_reward.get("drop", ""), int(_reward.get("amount", 1)), output_marker.global_position)
	ground.emit(cost, rewards)

func _prompt_text()->String:
	return "Grind %s" % LootItems.describe(cost)
