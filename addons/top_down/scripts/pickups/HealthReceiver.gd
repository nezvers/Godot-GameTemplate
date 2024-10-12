class_name HealthReceiver
extends Node

@export var area_receiver:AreaReceiver2D
@export var damage_receiver:DamageReceiver
## Resource node holds HealthResource
@export var resource_node:ResourceNode

var health_resource:HealthResource

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	
	# Hack to generate type_id
	var temp_res: = HealthTransmision.new()
	var temp_type_int:int = typeof(temp_res)
	
	# creates a signal with it's argument signature
	area_receiver.add_signal("health", [{ "name": "health", "type": temp_type_int }])
	area_receiver.connect("health", receive)

func receive(health_transmision:HealthTransmision)->void:
	## Health transmission takes care of processing health
	health_transmision.apply(health_resource)
