class_name EnemyManager
extends Node

## TODO: place enemy types and count for each wave
@export var wave_setup:Array[int]

func _ready()->void:
	## BUG: Workaround for stupid bug
	wave_setup = wave_setup.duplicate()
