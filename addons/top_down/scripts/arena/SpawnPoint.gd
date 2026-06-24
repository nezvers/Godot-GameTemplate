class_name SpawnPoint
extends Marker2D

## Which arena section this spawn point feeds (node in the same room scene).
@export var section:ArenaSection

@export var boss_position:bool

func _ready()->void:
	assert(section != null)
	if !boss_position:
		section.register_position(global_position)
	else:
		section.register_boss_position(global_position)
