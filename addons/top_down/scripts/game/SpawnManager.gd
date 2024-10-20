extends Node

@export var enemy_spawner:EnemySpawner
## Spawning tries to keep active count
@export var active_count_target:int = 3
## Remaining enemy count that needs to be spawned
@export var remaining_count:int = 0

var active_count:int

func _ready()->void:
	enemy_spawner.object_instantiated.connect(object_instantiated)

## Creates a wave of enemies that needs to be spawned
func set_remaining(value:int)->void:
	remaining_count = max(value, 0)

func add_active(value:int)->void:
	active_count += value

func object_instantiated(inst:Node2D)->void:
	set_remaining(remaining_count - 1)
	add_active(1)
	inst.tree_exiting.connect(instance_removed)

func instance_removed()->void:
	add_active(-1)

func _process(_delta:float)->void:
	# TODO: something is wrong. Spawned are more than needed.
	if remaining_count < 1:
		return
	if active_count >= active_count_target:
		return
	
	enemy_spawner.spawn_scene()
