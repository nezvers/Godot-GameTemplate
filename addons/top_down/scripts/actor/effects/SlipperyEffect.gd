## Water puddle: lowers acceleration so the actor slides and is slow to turn or stop.
class_name SlipperyEffect
extends PulseEffect

## Multiplier for acceleration (it also brakes) while on a wet floor
@export var acceleration_multiplier:float = 0.15

var movement_resource:ActorStatsResource

func _setup()->bool:
	movement_resource = resource_node.get_resource("movement")
	return movement_resource != null

func _start()->void:
	movement_resource.set_acceleration_multiplier(&"slippery", acceleration_multiplier)

func _stop()->void:
	movement_resource.set_acceleration_multiplier(&"slippery", 1.0)
