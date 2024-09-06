class_name MusicSetter
extends Node

@export var music_name:String

func _ready()->void:
	Music.start(music_name)
