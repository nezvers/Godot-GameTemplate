extends Node


#AUDIO
var VolumeMaster:float = 0.0 setget set_volume_master
var VolumeMusic:float = 0.0 setget set_volume_music
var VolumeSFX:float = 0.0 setget set_volume_sfx
const VolumeRange:float = 24.0 + 80.0

func _ready()->void:
	pass

#AUDIO
func get_volumes()->void:
	var Master:float	= db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	var Music:float 	= db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	var SFX:float 		= db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	
	set_volume_master(Master)
	set_volume_music(Music)
	set_volume_sfx(SFX)

func set_volume_master(volume:float)->void:
	VolumeMaster = volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(VolumeMaster))

func set_volume_music(volume:float)->void:
	VolumeMusic = volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(VolumeMusic))

func set_volume_sfx(volume:float)->void:
	VolumeSFX = volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(VolumeSFX))


#SAVING AUDIO
func get_audio_data()->Dictionary:
	var audio_data:Dictionary = {}
	audio_data["Master"] = SettingsAudio.VolumeMaster
	audio_data["Music"] = SettingsAudio.VolumeMusic
	audio_data["SFX"] = SettingsAudio.VolumeSFX
	return audio_data

#LOADING AUDIO
func set_audio_data(audio:Dictionary)->void:
	SettingsAudio.set_volume_master(audio.Master)
	SettingsAudio.set_volume_music(audio.Music)
	SettingsAudio.set_volume_sfx(audio.SFX)





