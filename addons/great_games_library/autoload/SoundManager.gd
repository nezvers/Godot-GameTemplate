## Singleton script for managing sounds.
## It allows sounds to be played after scene is freed
extends Node

## During _ready will be created new SoundPlayers
@export var start_count:int = 10

## Name of the audio channel where sounds will be played
@export var audio_bus:StringName


var player_list:Array[SoundPlayer]

func create_player()->void:
	var new_player:SoundPlayer = SoundPlayer.new()
	new_player.bus = audio_bus
	add_child(new_player)
	player_list.append(new_player)

func _ready()->void:
	if audio_bus.is_empty():
		printerr("SoundManager [INFO]: Audio buss name is empty. Will play through Master.")
	for i in start_count:
		create_player()

func get_player()->SoundPlayer:
	if player_list.is_empty():
		create_player()
	return player_list.pop_back()

func play(sound:SoundResource)->void:
	if sound.sound_player != null:
		sound.play(sound.sound_player)
		return
	var player:SoundPlayer = get_player()
	player.finished.connect(return_player.bind(player,sound), CONNECT_ONE_SHOT)
	sound.play(player)

func return_player(player:SoundPlayer, sound:SoundResource)->void:
	sound.sound_player = null
	player_list.append(player)
