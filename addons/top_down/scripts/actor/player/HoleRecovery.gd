class_name HoleRecovery
extends Node

@export var safe_tile_tracker:SafeTileTracker
@export var resource_node:ResourceNode
@export var hole_trigger:HoleTrigger
@export var hole_damage:int = 10

var health_resource:HealthResource

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	assert(health_resource != null)
	# Connect one point damage to health
	hole_trigger.hole_touched.connect(on_hole_touched)

func on_hole_touched()->void:
	health_resource.add_hp(-hole_damage)
	if health_resource.is_dead:
		return
	safe_tile_tracker.move_to_safe_position()
