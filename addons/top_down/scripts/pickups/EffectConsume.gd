class_name EffectConsume
extends Node

@export var data_transmitter:DataTransmitter
@export var animation_player:AnimationPlayer
@export var fade_out_animation:StringName = "fade_out"
@export var sounds_resource:SoundResource

func _ready()->void:
	data_transmitter.success.connect(on_success, CONNECT_ONE_SHOT)

func on_success()->void:
	sounds_resource.play_managed()
	animation_player.play(fade_out_animation)
