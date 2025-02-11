class_name BigJellyAi
extends Node

@export var player_reference:ReferenceNodeResource

@export var chase:BigJellyChase

@export var actor_damage:ActorDamage

## Move closer when too far
@export var out_of_range_distance:float = 4 * 32

## TODO: could be used for difficulity
@export var max_jump_distance:float = 3 * 32.0

## When out of range allow bigger jumps
@export var max_jump_close_in:float = 4 * 32.0

@export var shoot_slime:BigJellyShootSlime

var enabled:bool

var CLOSE_IN_MAX_JUMPS:int = 4
var close_in_counter:int
var tween_wait:Tween

func _ready()->void:
	close_in_counter = CLOSE_IN_MAX_JUMPS
	chase.finished.connect(_state_update.call_deferred)
	actor_damage.actor_died.connect(owner.queue_free)
	player_reference.listen(self, _on_player_changed)
	# DEATH

func _on_player_changed()->void:
	enabled = player_reference.node != null
	_state_update.call_deferred()

## after each action decide what to do
func _state_update()->void:
	if !enabled:
		return
	if close_in_counter > 0 && _need_move_in_range():
		close_in_counter -= 1
		chase.target_calculation(player_reference.node.global_position, player_reference.node.velocity, max_jump_close_in)
		chase.jump_at_target()
		return
	close_in_counter = CLOSE_IN_MAX_JUMPS
	if shoot_slime.shoot(player_reference.node.global_position):
		## TODO: has to perform something to keep loop going
		if tween_wait != null:
			tween_wait.kill()
		tween_wait = create_tween()
		tween_wait.tween_callback(_state_update.call_deferred).set_delay(2.0)
		return
	
	chase.target_calculation(player_reference.node.global_position, player_reference.node.velocity, max_jump_distance)
	chase.jump_at_target()


## test if too far
func _need_move_in_range()->bool:
	chase.target_calculation(player_reference.node.global_position, Vector2.ZERO, 9999.0)
	if chase.distance_length < out_of_range_distance:
		return false
	return true
	
