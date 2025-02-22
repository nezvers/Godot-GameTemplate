## Resource used to carry an information how a sound should be played
class_name SoundResource
extends Resource

## Lowest random pitch
@export var pitch_min:float = 1.0

## Highest random pitch
@export var pitch_max:float = 1.0

## Volume of a played sound
@export_range(-80.0, +24.0) var volume:float = 0.0

## Time interval when sound is not played again
@export var retrigger_time:float = 0.032

## Pitch increase when repeated fast
@export var pitch_add:float = 0.0

## If triggered in this time again, a pitch is added
@export var pitch_cooldown:float

## Time to return to original pitch
@export var pitch_return:float

## Audio sample used
@export var sound:AudioStream

## keep track of trigger time
var last_play_time:float

## time since last trigger
var delta:float

## Audio player assigned to use this resource
var sound_player:SoundPlayer

## keep track of the pitch
var pitch:float

## Base audio sample getting, intended to be overriten
func get_sound()->AudioStream:
	return sound

## Pitch calculation
func get_pitch()->float:
	if delta < pitch_cooldown:
		pitch = pitch + pitch_add
		return pitch
	elif delta < pitch_cooldown + pitch_return:
		var pitch_lerp:float = lerp(pitch_min, pitch_max, 0.5)
		var t:float = (delta - pitch_cooldown) / pitch_return
		pitch = lerp(pitch, pitch_lerp, t)
	else:
		pitch = randf_range(pitch_min, pitch_max)
	return pitch

## Volume getting function, meant to be overriten
func get_volume()->float:
	return volume

## Plays the sound
func play(_sound_player:SoundPlayer)->void:
	var time: = Time.get_ticks_msec() * 0.001
	if time < last_play_time + retrigger_time:
		return
	delta = time - last_play_time
	sound_player = _sound_player
	last_play_time = time
	sound_player.stream = get_sound()
	sound_player.pitch_scale = get_pitch()
	sound_player.volume_db = get_volume()
	sound_player.play()

## Gets played by SoundManager singleton
func play_managed()->void:
	SoundManager.play(self)

## Stops sound
func stop()->void:
	if sound_player == null:
		return
	sound_player.stop()
