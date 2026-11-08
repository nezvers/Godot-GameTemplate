## Boss brain on top of enemy_ai: walks with BotInput, and when an attack (child BossAttack) is
## available by cooldown, distance and health it stops, telegraphs (animation, tint, BossTelegraph),
## performs it and recovers. Below enrage_health the boss gets faster in every way.
class_name BossAttackLoop
extends Node

signal attack_started(attack:BossAttack)
## Windup over, perform() starts
signal attack_performing(attack:BossAttack)
## Back to walking (finished or interrupted)
signal attack_ended
signal enraged

@export var bot_input:BotInput

@export var target_finder:TargetFinder

@export var resource_node:ResourceNode

@export var character_states:CharacterStates

@export var animation_player:AnimationPlayer

## Tinted during windup, separate from damage flash material
@export var tint_node:CanvasItem

@export var windup_color:Color = Color(1.0, 0.5, 0.4)

@export var enrage_color:Color = Color(1.0, 0.8, 0.8)

## Time after spawning before the first attack
@export var start_delay:float = 1.5

## Walking time between attacks
@export var attack_gap:float = 0.8

## Health ratio that starts enrage
@export_range(0.0, 1.0) var enrage_health:float = 0.4

@export var enrage_speed:float = 1.3

## Multiplies windup, cooldown and gap time while enraged
@export var enrage_time_scale:float = 0.7

var attacks:Array[BossAttack]
var current:BossAttack
var next_attack_time:float
var is_enraged:bool
## Changes when attack sequence must stop (death, leaving tree)
var run_id:int
var health_resource:HealthResource
var stats_resource:ActorStatsResource
var tint_tween:Tween

func _ready()->void:
	attacks.clear()
	for _child:Node in get_children():
		if _child is BossAttack:
			attacks.append(_child)
	health_resource = resource_node.get_resource("health")
	stats_resource = resource_node.get_resource("movement")
	if !target_finder.target_update.is_connected(_on_target_update):
		target_finder.target_update.connect(_on_target_update)
	if !health_resource.dead.is_connected(_interrupt):
		health_resource.dead.connect(_interrupt)
	# in case used with PoolNode
	request_ready()

func _enter_tree()->void:
	run_id += 1
	current = null
	is_enraged = false
	next_attack_time = _time() + start_delay
	for _attack:BossAttack in attacks:
		_attack.ready_time = 0.0

func _exit_tree()->void:
	_interrupt()
	_resume()
	if stats_resource != null:
		stats_resource.set_speed_multiplier(&"enrage", 1.0)
	if tint_node != null:
		tint_node.self_modulate = Color.WHITE

func _time()->float:
	return Time.get_ticks_msec() * 0.001

func _health_ratio()->float:
	return health_resource.hp / maxf(health_resource.max_hp, 1.0)

func _time_scale()->float:
	return enrage_time_scale if is_enraged else 1.0

func _on_target_update()->void:
	if current != null || health_resource.is_dead:
		return
	_update_enrage()
	if target_finder.target_count < 1:
		return
	var _time_now:float = _time()
	if _time_now < next_attack_time:
		return
	var _target:Node2D = target_finder.closest
	var _distance:float = _target.global_position.distance_to(bot_input.global_position)
	var _attack:BossAttack = _pick_attack(_time_now, _distance, _health_ratio(), _target)
	if _attack == null:
		return
	_run_attack(_attack, _target)

func _pick_attack(time:float, distance:float, health_ratio:float, target:Node2D)->BossAttack:
	var _available:Array[BossAttack]
	var _total:float = 0.0
	for _attack:BossAttack in attacks:
		if _attack.is_available(time, distance, health_ratio) && _attack.can_target(target):
			_available.append(_attack)
			_total += _attack.weight
	if _available.is_empty():
		return null
	var _roll:float = randf() * _total
	for _attack:BossAttack in _available:
		_roll -= _attack.weight
		if _roll <= 0.0:
			return _attack
	return _available.back()

func _update_enrage()->void:
	if is_enraged || _health_ratio() > enrage_health:
		return
	is_enraged = true
	stats_resource.set_speed_multiplier(&"enrage", enrage_speed)
	if tint_node != null && current == null:
		tint_node.self_modulate = enrage_color
	enraged.emit()

func _run_attack(attack:BossAttack, target:Node2D)->void:
	var _id:int = run_id
	current = attack
	bot_input.set_enabled(false)
	bot_input.input_resource.set_action(false)
	character_states.set_enabled(false)

	var _windup:float = attack.windup * _time_scale()
	attack.prepare(target)
	show_windup(attack, _windup, self)
	attack_started.emit(attack)

	await _wait(_windup)
	if _id != run_id:
		return
	show_perform(attack)
	attack_performing.emit(attack)

	await attack.perform()
	if _id != run_id:
		return
	attack.stop()
	attack.ready_time = _time() + attack.cooldown * _time_scale()

	await _wait(attack.recovery + attack.extra_recovery)
	if _id != run_id:
		return
	_resume()
	next_attack_time = _time() + attack_gap * _time_scale()

## Back to walking
func _resume()->void:
	var _was:bool = current != null
	current = null
	show_resume()
	bot_input.set_enabled(true)
	if _was:
		attack_ended.emit()

# --- Visuals (also played on a co-op guest's copy, whose loop is switched off) ---

## Windup animation stretched over `windup`, tint flicker and ground warning.
## Tweens belong to `tween_owner` (a puppet's loop doesn't process).
func show_windup(attack:BossAttack, windup:float, tween_owner:Node)->void:
	character_states.set_enabled(false)
	_play_animation(attack.animation, windup)
	_tint(windup, tween_owner)
	if attack.telegraph != null:
		attack.telegraph.show_telegraph(windup)

func show_perform(attack:BossAttack)->void:
	if attack.telegraph != null:
		attack.telegraph.hide_telegraph()
	_stop_tint()
	if !attack.perform_animation.is_empty() && animation_player.has_animation(attack.perform_animation):
		animation_player.play(attack.perform_animation, -1.0, attack.perform_animation_speed)

func show_resume()->void:
	_stop_tint()
	for _attack:BossAttack in attacks:
		if _attack.telegraph != null:
			_attack.telegraph.hide_telegraph()
	# force CharacterStates to play idle/walk again after the attack animation
	character_states.state = CharacterStates.State.NONE
	character_states.set_enabled(true)

## Stops attack in progress, on death the boss stays still until removed
func _interrupt()->void:
	run_id += 1
	if current != null:
		current.stop()
		if current.telegraph != null:
			current.telegraph.hide_telegraph()
		current = null
		attack_ended.emit()
	_stop_tint()

func _wait(time:float)->void:
	await get_tree().create_timer(time, false, true).timeout

func _play_animation(animation:StringName, time:float)->void:
	if animation.is_empty() || !animation_player.has_animation(animation):
		return
	var _length:float = animation_player.get_animation(animation).length
	animation_player.play(animation, -1.0, _length / maxf(time, 0.05))

## Flicker towards windup_color, the attack is coming
func _tint(time:float, tween_owner:Node)->void:
	if tint_node == null:
		return
	if tint_tween != null:
		tint_tween.kill()
	var _base:Color = enrage_color if is_enraged else Color.WHITE
	tint_tween = tween_owner.create_tween().set_loops(maxi(1, int(time / 0.2)))
	tint_tween.tween_property(tint_node, "self_modulate", windup_color, 0.1)
	tint_tween.tween_property(tint_node, "self_modulate", _base, 0.1)

func _stop_tint()->void:
	if tint_tween != null:
		tint_tween.kill()
	if tint_node != null:
		tint_node.self_modulate = enrage_color if is_enraged else Color.WHITE
