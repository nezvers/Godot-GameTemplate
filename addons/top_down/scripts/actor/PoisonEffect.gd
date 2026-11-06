## Damage over time while "poison" BoolResource keeps getting set (acid puddle).
## TrapTransmission with repeat_while_inside sets it every physics frame while inside.
## Actors without "poison" resource are not affected.
class_name PoisonEffect
extends Node

@export var resource_node:ResourceNode

## BoolResource puddles set; "acid" (player acid puddle) is created when missing
@export var effect_name:StringName = &"poison"

## Damage per tick
@export var damage:float = 1.0

## Seconds between ticks
@export var tick_time:float = 0.5

## Seconds the poison stays after the last pulse (after leaving the puddle)
@export var linger_time:float = 0.1

var poison_bool:BoolResource
var health_resource:HealthResource
var damage_resource:DamageResource
var remaining_time:float
var tick_remaining:float

func _ready()->void:
	poison_bool = PulseEffect.ensure_bool(resource_node, effect_name)
	health_resource = resource_node.get_resource("health")
	damage_resource = resource_node.get_resource("damage")
	if poison_bool == null || health_resource == null:
		set_physics_process(false)
		return
	poison_bool.changed_true.connect(_on_pulse)
	set_physics_process(true)

	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(_on_tree_exiting, CONNECT_ONE_SHOT)

func _on_pulse()->void:
	# reset so next pulse triggers changed_true again
	poison_bool.set_value(false)
	if remaining_time <= 0.0:
		# first tick right away
		tick_remaining = 0.0
	remaining_time = linger_time

func _physics_process(delta:float)->void:
	if remaining_time <= 0.0:
		return
	remaining_time -= delta
	tick_remaining -= delta
	if tick_remaining > 0.0:
		return
	tick_remaining += tick_time
	if health_resource.is_dead:
		return
	health_resource.add_hp(-damage)
	if damage_resource != null:
		# damage number popup
		damage_resource.receive_points(damage)

func _on_tree_exiting()->void:
	remaining_time = 0.0
	poison_bool.changed_true.disconnect(_on_pulse)
