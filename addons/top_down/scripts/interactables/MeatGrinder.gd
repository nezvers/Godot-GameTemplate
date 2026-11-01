## Turns meat chunks into a health pickup.
class_name MeatGrinder
extends Interactable

@export var meat_resource:ScoreResource
@export var meat_cost:int = 3
@export var health_pickup_instance:InstanceResource
@export var output_marker:Marker2D
## Frame 0 idle, frames 1-3 the crank turning.
@export var sprite:Sprite2D

const CRANK_FRAMES:Array[int] = [1, 2, 3, 1, 2, 3, 0]
const FRAME_TIME:float = 0.07

func _can_use()->bool:
	return meat_resource.can_spend(meat_cost)

func _use()->void:
	meat_resource.spend(meat_cost)
	busy = true
	var _tween:Tween = create_tween()
	for _frame:int in CRANK_FRAMES:
		_tween.tween_callback(sprite.set_frame.bind(_frame))
		_tween.tween_interval(FRAME_TIME)
	_tween.tween_callback(_finish)

func _finish()->void:
	busy = false
	var _position:Vector2 = output_marker.global_position
	health_pickup_instance.instance(func (inst:Node2D)->void: inst.global_position = _position)

func _prompt_text()->String:
	return "Grind meat %d/%d" % [meat_resource.value, meat_cost]
