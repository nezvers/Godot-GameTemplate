## Used to play SoundResource
class_name SoundPlayer
extends AudioStreamPlayer

@export var sound_resource:SoundResource

## Play the sound from SoundResource
func play_sound()->void:
	if sound_resource == null:
		print(owner.name, ": ", name, " doesn't have a sound")
		return
	sound_resource.play(self)


## Used as a sound emitter to play the sound through SoundManager
func play_managed_sound()->void:
	if sound_resource == null:
		print(owner.name, ": ", name, " doesn't have a sound")
		return
	sound_resource.play_managed()
