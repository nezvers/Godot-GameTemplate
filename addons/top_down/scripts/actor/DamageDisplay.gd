class_name DamageDisplay
extends Node

@export var resource_node:ResourceNode
@export var damage_points_instance_resource:InstanceResource

const UPDATE_INTERVAL:float = 0.3
var last_time:float
var last_points:DamagePoints
var total_points:float

func _ready()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	_health_resource.damage_data.connect(on_damage_data)

func on_damage_data(damage_resource:DamageResource)->void:
	var _time:float = Time.get_ticks_msec() * 0.001
	if last_points && _time < last_time + UPDATE_INTERVAL:
		last_time = _time
		total_points += damage_resource.get_total_damage()
		last_points.set_displayed_points(total_points, damage_resource.is_critical)
		return
	
	last_time = _time
	total_points = damage_resource.get_total_damage()
	var _config_callback:Callable = func (inst:Node2D)->void:
		# give offset to appear on body position
		inst.global_position = owner.global_position + Vector2(0.0, -8.0)
		(inst as DamagePoints).set_displayed_points(total_points, damage_resource.is_critical)
	
	last_points = damage_points_instance_resource.instance(_config_callback)
