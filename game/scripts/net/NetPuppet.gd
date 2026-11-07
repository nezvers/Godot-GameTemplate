## Drives a copy of an enemy the host owns (NetEntities): eases it towards the
## positions in the host's snapshots and feeds the move direction to its input,
## so walk animations and facing follow. Its hp shows the host's share.
class_name NetPuppet
extends Node

## Further than this from the reported spot: jump there instead of catching up.
const SNAP_DISTANCE:float = 64.0
const CATCH_UP:float = 0.3

var target_position:Vector2
var _input:InputResource
var _health:HealthResource
var _hp_ratio:float = 1.0

func _ready()->void:
	# pooled enemies get new resources on every reuse
	request_ready()
	var _resources:ResourceNode = get_parent().get_node_or_null("ResourceNode")
	if _resources != null:
		_input = _resources.get_resource("input")
		_health = _resources.get_resource("health")
	process_physics_priority = 10

func reset(at:Vector2)->void:
	target_position = at
	_hp_ratio = 1.0

func push(at:Vector2, hp_ratio:float)->void:
	target_position = at
	if _health != null && !is_equal_approx(hp_ratio, _hp_ratio):
		_hp_ratio = hp_ratio
		# never 0 here: dying is the host's call (NetEntities._despawn)
		_health.hp = maxf(_health.max_hp * hp_ratio, 1.0)
		_health.hp_changed.emit()

func _physics_process(_delta:float)->void:
	var _body:Node2D = get_parent() as Node2D
	if _body == null:
		return
	var _gap:Vector2 = target_position - _body.global_position
	if _gap.length() > SNAP_DISTANCE:
		_body.global_position = target_position
		_gap = Vector2.ZERO
	else:
		_body.global_position += _gap * CATCH_UP
	if _input != null:
		var _axis:Vector2 = _gap.normalized() if _gap.length() > 0.5 else Vector2.ZERO
		_input.set_axis(_axis)
		if _axis != Vector2.ZERO:
			_input.set_aim_direction(_axis)
