class_name SpawnPoint
extends Marker2D

## Which arena section this spawn point feeds (node in the same room scene).
@export var section:ArenaSection

@export var boss_position:bool

## Max enemies this point may host alive at once.
@export_range(1, 6) var max_simultaneous:int = 1

## Live enemies currently hosted by this point (section-maintained).
var active_count:int = 0

func _ready()->void:
	assert(section != null)
	active_count = 0
	if !boss_position:
		section.register_point(self)
	else:
		section.register_boss_point(self)
