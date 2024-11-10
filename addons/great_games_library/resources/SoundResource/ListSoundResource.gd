extends SoundResource
class_name ListSoundResource

@export var sound_list:Array[AudioStream]
@export var random_order:bool

var index:int = 0

func get_sound()->AudioStream:
	if random_order:
		return sound_list[randi() % sound_list.size()]
	else:
		index = (index +1) % sound_list.size()
		return sound_list[index]
