class_name EffectConsume
extends Node

@export var effect_transmitter:EffectTransmitter
@export var animation_player:AnimationPlayer
@export var fade_out_animation:StringName = "fade_out"
@export var sounds_resource:SoundResource

func _ready()->void:
	effect_transmitter.consumed.connect(on_consumed, CONNECT_ONE_SHOT)

func on_consumed()->void:
	sounds_resource.play_managed()
	animation_player.play(fade_out_animation)
	animation_player.animation_finished.connect(remove, CONNECT_ONE_SHOT)

func remove(_anim:StringName = "")->void:
	owner.queue_free()
