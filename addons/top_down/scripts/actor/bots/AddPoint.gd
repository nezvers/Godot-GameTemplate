extends Node

@export var resource_node:ResourceNode
@export var score_resource:ScoreResource


func _ready():
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if !_health_resource.dead.is_connected(score_resource.add_point):
		_health_resource.dead.connect(score_resource.add_point)
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(_remove_connection.bind(_health_resource), CONNECT_ONE_SHOT)

func _remove_connection(health_resource:HealthResource)->void:
	if health_resource.dead.is_connected(score_resource.add_point):
		health_resource.dead.disconnect(score_resource.add_point)
	else:
		pass
