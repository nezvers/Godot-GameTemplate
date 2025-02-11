class_name ProximityAttack
extends Node

@export var target_finder:TargetFinder
@export var bot_input:BotInput

var enabled:bool

var tween_timer:Tween

func _enter_tree() -> void:
	enabled = false
	if tween_timer != null:
		tween_timer.kill()
	tween_timer = create_tween()
	tween_timer.tween_callback(set_enabled.bind(true)).set_delay(1.0)

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
	var distance:float = (target_finder.closest.global_position - bot_input.global_position).length()
	bot_input.input_resource.set_action(distance <= bot_input.attack_distance)
