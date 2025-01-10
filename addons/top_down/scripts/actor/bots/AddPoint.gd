extends Node

@export var resource_node:ResourceNode
@export var score_resource:ScoreResource


func _ready():
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if !_health_resource.dead.is_connected(score_resource.add_point):
		_health_resource.dead.connect(score_resource.add_point)
	
	# in case used with PoolNode
	request_ready()
	tree_exiting.connect(_health_resource.dead.disconnect.bind(score_resource.add_point), CONNECT_ONE_SHOT)
