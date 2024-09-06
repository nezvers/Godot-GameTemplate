extends SoundResource
class_name NestedSoundResource

@export var sound_resource_list:Array[SoundResource]
@export var random_order:bool

var index:int = 0

func play(_sound_player:SoundPlayer)->void:
	if random_order:
		sound_resource_list.pick_random().play(_sound_player)
	else:
		index = (index +1) % sound_resource_list.size()
		sound_resource_list[index].play(_sound_player)
