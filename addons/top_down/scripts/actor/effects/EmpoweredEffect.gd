## Blood puddle: raises the damage the actor deals while standing in it.
## Read by ProjectileSpawner through ActorStatsResource.get_damage_multiply().
class_name EmpoweredEffect
extends PulseEffect

@export var damage_multiplier:float = 1.5

var movement_resource:ActorStatsResource

func _setup()->bool:
	movement_resource = resource_node.get_resource("movement")
	return movement_resource != null

func _start()->void:
	movement_resource.set_damage_multiplier(&"empowered", damage_multiplier)

func _stop()->void:
	movement_resource.set_damage_multiplier(&"empowered", 1.0)
