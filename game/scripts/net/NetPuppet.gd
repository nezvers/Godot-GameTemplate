## Drives a copy of an enemy the host owns (NetEntities): plays back the host's
## snapshots a little behind (NetInterp), so it walks smoothly between them, and
## feeds the shown motion to its input, so walk animations and facing follow.
## Its hp shows the host's share; hits it takes on the host flash here too.
class_name NetPuppet
extends Node

## Slower than this (px/s) it stands; faster than WALK_START it walks. The gap
## between them keeps it from flickering between the two.
const WALK_STOP:float = 3.0
const WALK_START:float = 6.0

var interp:NetInterp = NetInterp.new()
var _input:InputResource
var _health:HealthResource
var _damage:DamageResource
var _hp_ratio:float = 1.0
var _walking:bool

func _ready()->void:
	# pooled enemies get new resources on every reuse
	request_ready()
	var _resources:ResourceNode = get_parent().get_node_or_null("ResourceNode")
	if _resources != null:
		_input = _resources.get_resource("input")
		_health = _resources.get_resource("health")
		_damage = _resources.get_resource("damage")
	process_physics_priority = 10

func reset(_at:Vector2)->void:
	# stays where it spawned until the first snapshot
	interp.clear()
	_hp_ratio = 1.0
	_walking = false

## A host snapshot: where it was at host time `sent`.
func push(sent:float, at:Vector2, hp_ratio:float)->void:
	interp.push(sent, at)
	if _health != null && !is_equal_approx(hp_ratio, _hp_ratio):
		_hp_ratio = hp_ratio
		# never 0 here: dying is the host's call (NetEntities._despawn)
		_health.hp = maxf(_health.max_hp * hp_ratio, 1.0)
		_health.hp_changed.emit()

## A hit landed on the real one: flash, sound and damage number, hp untouched.
func play_hit(points:float, critical:bool)->void:
	if _health != null:
		_health.damaged.emit()
	if _damage != null && points > 0.0:
		_damage.receive_points(points, critical)

func _physics_process(_delta:float)->void:
	var _body:Node2D = get_parent() as Node2D
	if _body == null || interp.is_empty():
		return
	var _at:Vector2 = interp.position()
	if _at.is_finite():
		_body.global_position = _at
	if _input == null:
		return
	var _velocity:Vector2 = interp.velocity()
	var _speed:float = _velocity.length()
	_walking = _speed > (WALK_STOP if _walking else WALK_START)
	var _axis:Vector2 = _velocity / _speed if _walking else Vector2.ZERO
	_input.set_axis(_axis)
	if _walking:
		_input.set_aim_direction(_axis)
