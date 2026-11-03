class_name ProximityAttack
extends Node

@export var target_finder:TargetFinder
@export var bot_input:BotInput

## Seconds after spawning before the first attack.
@export var start_delay:float = 1.0

## Ranged bots: attack only when nothing from the environment is in the way
@export var require_line_of_sight:bool = false

@export var raycast:RayCast2D

var enabled:bool

var tween_timer:Tween

func _enter_tree() -> void:
	enabled = false
	if tween_timer != null:
		tween_timer.kill()
	tween_timer = create_tween()
	tween_timer.tween_callback(set_enabled.bind(true)).set_delay(start_delay)

func _ready()->void:
	target_finder.target_update.connect(_on_target_update)

func set_enabled(value:bool)->void:
	enabled = value

func _on_target_update()->void:
	if !enabled:
		return
	
	if target_finder.target_count < 1:
		bot_input.input_resource.set_action(false)
		return
	var _difference:Vector2 = target_finder.closest.global_position - bot_input.global_position
	var _in_range:bool = _difference.length() <= bot_input.attack_distance
	if _in_range && require_line_of_sight:
		raycast.target_position = _difference
		raycast.force_raycast_update()
		_in_range = !raycast.is_colliding()
	bot_input.input_resource.set_action(_in_range)
