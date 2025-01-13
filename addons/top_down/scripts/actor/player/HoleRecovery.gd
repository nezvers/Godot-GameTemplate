class_name HoleRecovery
extends Node

@export var safe_tile_tracker:SafeTileTracker

@export var resource_node:ResourceNode

@export var hole_trigger:HoleTrigger

## Damage applied when stepping on a hole
@export var hole_damage:int = 10

var health_resource:HealthResource

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	assert(health_resource != null)
	# Connect one point damage to health
	hole_trigger.hole_touched.connect(_on_hole_touched)
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(hole_trigger.hole_touched.disconnect.bind(_on_hole_touched), CONNECT_ONE_SHOT)

func _on_hole_touched()->void:
	if health_resource.is_dead:
		return
	health_resource.add_hp(-hole_damage)
	safe_tile_tracker.move_to_safe_position()
