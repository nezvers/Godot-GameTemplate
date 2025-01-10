class_name ProximityAttack
extends Node

@export var target_finder:TargetFinder
@export var bot_input:BotInput

func _ready()->void:
	target_finder.target_update.connect(_on_target_update)

func _on_target_update()->void:
	if target_finder.target_count < 1:
		bot_input.input_resource.set_action(false)
		return
	var distance:float = (target_finder.closest.global_position - bot_input.global_position).length()
	bot_input.input_resource.set_action(distance <= bot_input.attack_distance)
