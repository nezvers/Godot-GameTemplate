extends Node

@export var resource_node:ResourceNode
@export var score_resource:ScoreResource


func _ready():
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if !_health_resource.dead.is_connected(score_resource.add_point):
		_health_resource.dead.connect(score_resource.add_point)
