class_name AnimationHelper
extends Node

@export var animation_player:AnimationPlayer

## Allows for AnimationPlayers to call next animation
func play(animation:StringName, reset:bool = false)->void:
	assert(animation_player != null)
	if reset:
		animation_player.stop()
	animation_player.play(animation)
