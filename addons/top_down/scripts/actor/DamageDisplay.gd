class_name DamageDisplay
extends Node

@export var resource_node:ResourceNode
@export var damage_points_instance_resource:InstanceResource

const UPDATE_INTERVAL:float = 0.3
var last_time:float
var last_points:DamagePoints
var last_critical:bool
var total_points:float

func _ready()->void:
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	assert(_damage_resource != null)
	_damage_resource.received_damage_points.connect(_on_damage_points)
	
	# in case used with PoolNode
	request_ready()

## TODO: with shotgun possible to receive altering criticality and create more than 2 points
func _on_damage_points(points:float, is_critical:bool)->void:
	var _time:float = Time.get_ticks_msec() * 0.001
	if last_critical == is_critical && last_points && _time < last_time + UPDATE_INTERVAL:
		last_time = _time
		total_points += points
		last_points.set_displayed_points(total_points, last_critical)
		return
	
	last_time = _time
	total_points = points
	last_critical = is_critical
	var _config_callback:Callable = func (inst:Node2D)->void:
		# give offset to appear on body position
		inst.global_position = owner.global_position + Vector2(0.0, -8.0)
		(inst as DamagePoints).set_displayed_points(total_points, last_critical)
	
	last_points = damage_points_instance_resource.instance(_config_callback)
