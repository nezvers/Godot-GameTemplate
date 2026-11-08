## Drives a copy of an enemy the host owns (NetEntities): plays back the host's
## snapshots a little behind (NetInterp), so it walks smoothly between them, and
## feeds the shown motion to its input, so walk animations and facing follow.
## Its hp shows the host's share; hits it takes on the host flash here too.
## Boss attacks (windup, telegraph, charge) and jumps are played here on the
## host's word (NetEntities._enemy_attack / _enemy_jump): the AI that plays them
## on the host is switched off on a copy.
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
## Receiver layer while a jump makes the copy unhittable (0: not jumping)
var _saved_layer:int
## Jump this copy is in the air with (play_jump), until it lands
var _jumping:JumpMove

enum AttackPhase {WINDUP, PERFORM, END}
const MAX_WINDUP:float = 10.0

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
	_jumping = null
	_set_dash(false)
	_restore_receiver()

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

## The host's boss started, performed or finished attack `index` of its loop.
func play_attack(phase:int, index:int, windup:float, tele_top:bool, tele_pos:Vector2, tele_vector:Vector2, tele_radius:float, tele_color:Color)->bool:
	var _loop:BossAttackLoop = _attack_loop()
	if _loop == null:
		return false
	if phase == AttackPhase.END:
		_loop.show_resume()
		return true
	if index < 0 || index >= _loop.attacks.size():
		return false
	var _attack:BossAttack = _loop.attacks[index]
	if phase == AttackPhase.PERFORM:
		_loop.show_perform(_attack)
		return true
	if phase != AttackPhase.WINDUP || !is_finite(windup):
		return false
	var _telegraph:BossTelegraph = _attack.telegraph
	if _telegraph != null && tele_pos.is_finite() && tele_vector.is_finite() && is_finite(tele_radius):
		# top level (a jump's landing spot) is in world space, else beside the body
		_telegraph.top_level = tele_top
		_telegraph.position = tele_pos
		_telegraph.vector = tele_vector
		_telegraph.radius = clampf(tele_radius, 0.0, 1000.0)
		_telegraph.color = tele_color
	_loop.show_windup(_attack, clampf(windup, 0.05, MAX_WINDUP), self)
	return true

func _attack_loop()->BossAttackLoop:
	for _child:Node in get_parent().get_children():
		if _child is BossAttackLoop:
			return _child
	return null

## The host's enemy jumped with its JumpMove at `path` (from the enemy).
func play_jump(path:NodePath, time:float)->bool:
	var _move:JumpMove = get_parent().get_node_or_null(path) as JumpMove
	if _move == null || !is_finite(time):
		return false
	if !_move.has_meta(&"net_puppet_watched"):
		_move.set_meta(&"net_puppet_watched", true)
		_move.visual_landed.connect(_on_visual_landed.bind(_move))
	_jumping = _move
	# over a hole mid-hop, like the host's: holes here wait until it lands
	_set_dash(true)
	if _airborne_invulnerable(_move):
		var _receiver:Area2D = get_parent().get_node_or_null("AreaReceiver2D")
		if _receiver != null && _saved_layer == 0 && _receiver.collision_layer != 0:
			_saved_layer = _receiver.collision_layer
			_receiver.collision_layer = 0
	_move.play_visual(clampf(time, 0.05, MAX_WINDUP), self)
	return true

## Like the host's: a jelly can't be hit in the air, a boss jump only if it says so.
func _airborne_invulnerable(move:JumpMove)->bool:
	for _node:Node in get_parent().find_children("*", "", true, false):
		if _node is BigJellyJumpDamage && (_node as BigJellyJumpDamage).jump_move == move:
			return true
		if _node is BossJump && (_node as BossJump).jump_move == move:
			return (_node as BossJump).airborne_invulnerable
	return false

## The host's enemy landed: a copy still in the air (it plays a little behind)
## comes down now. A bloater's burst pops right on landing, so without this its
## death would remove the copy mid-hop, before the dust ring.
func land_now()->void:
	if _jumping == null || !is_instance_valid(_jumping):
		return
	if _jumping.move_tween != null:
		_jumping.move_tween.kill()
	_jumping._visual_landed(self)

func _on_visual_landed(move:JumpMove)->void:
	if _jumping != move:
		return
	_jumping = null
	_set_dash(false)
	_restore_receiver()
	# landing effects aren't sent: made here
	for _node:Node in get_parent().find_children("*", "", true, false):
		if _node is BigJellyChase && (_node as BigJellyChase).jump_move == move && (_node as BigJellyChase).landing_vfx != null:
			var _chase:BigJellyChase = _node
			var _at:Vector2 = move.character_body.global_position - _chase.target_offset
			_chase.landing_vfx.instance(func (inst:Node2D)->void: inst.global_position = _at)
			Net.entities.landings_played += 1
			return
		if _node is BossJump && (_node as BossJump).jump_move == move && (_node as BossJump).vfx != null:
			# the dust ring reaches the damage edge: the telegraph's radius, sent by the host
			var _jump:BossJump = _node
			var _radius:float = _jump.telegraph.radius if _jump.telegraph != null else _jump.get_damage_radius()
			# the landing spot the host marked (the copy's body trails it a little)
			var _at:Vector2 = _jump.telegraph.global_position if _jump.telegraph != null && _jump.telegraph.top_level else move.character_body.global_position
			_jump.vfx.instance(func (inst:Node2D)->void:
				inst.global_position = _at
				_jump._fit_vfx(inst, _radius))
			Net.entities.landings_played += 1
			return

func _set_dash(value:bool)->void:
	var _resources:ResourceNode = get_parent().get_node_or_null("ResourceNode") if get_parent() != null else null
	var _dash:BoolResource = _resources.get_resource("dash") as BoolResource if _resources != null else null
	if _dash != null && _dash.value != value:
		_dash.set_value(value)

func _restore_receiver()->void:
	if _saved_layer == 0:
		return
	var _receiver:Area2D = get_parent().get_node_or_null("AreaReceiver2D") if get_parent() != null else null
	if _receiver != null:
		_receiver.collision_layer = _saved_layer
	_saved_layer = 0

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
