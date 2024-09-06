class_name SoundEmitterNode
extends Node

@export var sound:SoundResource
@export var enabled:bool = true
@export var debug:bool = false

func set_enabled(value:bool)->void:
	enabled = value

func play()->void:
	if sound == null:
		return
	if !enabled:
		return
	if debug:
		pass
	sound.play_managed()

