extends Node

@export var area_receiver:AreaReceiver2D
## Resource node holds HealthResource
@export var resource_node:ResourceNode

var health_resource:HealthResource

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	
	# creates a signal with it's argument signature
	area_receiver.add_signal("hole")
	area_receiver.connect("hole", receive)

func receive()->void:
	# use all health
	health_resource.add_hp(-health_resource.hp)
