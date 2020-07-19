extends Node

onready var audio:AudioStreamPlayer = $AudioStreamPlayer

func play(music:Resource)->void:
	audio.stream = music
	audio.play()
