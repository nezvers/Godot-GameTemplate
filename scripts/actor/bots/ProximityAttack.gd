class_name ProximityAttack
extends Node

@export var attack_range:float = 16.0
@export var target_finder:TargetFinder
@export var bot_input:BotInput

func _ready()->void:
	target_finder.target_update.connect(on_target_update)

func on_target_update()->void:
	if target_finder.closest == null:
		bot_input.mover.input_resource.set_action(false)
		return
	var distance:float = (target_finder.closest.global_position - bot_input.global_position).length()
	bot_input.mover.input_resource.set_action(distance <= attack_range)
