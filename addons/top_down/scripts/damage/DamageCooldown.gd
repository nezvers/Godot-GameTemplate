extends Node

signal cooldown_started
signal cooldown_finished

@export var resource_node:ResourceNode
@export var cooldown_time:float = 0.0

var health_resource:HealthResource
var receive_damage_bool:BoolResource

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	assert(health_resource != null)
	receive_damage_bool = resource_node.get_resource("receive_damage")
	assert(receive_damage_bool != null)
	health_resource.damaged.connect(_start_cooldown)
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(health_resource.damaged.disconnect.bind(_start_cooldown), CONNECT_ONE_SHOT)

func _start_cooldown()->void:
	if cooldown_time == 0.0:
		return
	receive_damage_bool.set_value(false)
	var _tween:Tween = create_tween()
	_tween.tween_callback(_on_cooldown_finish).set_delay(cooldown_time)

## Called from tween
func _on_cooldown_finish()->void:
	receive_damage_bool.set_value(true)
	cooldown_finished.emit()
