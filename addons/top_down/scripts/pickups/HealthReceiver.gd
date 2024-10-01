class_name HealthReceiver
extends Node

@export var area_receiver:AreaReceiver2D
@export var damage_receiver:DamageReceiver

func _ready()->void:
	var temp_res: = HealthTransmision.new()
	var temp_type_int:int = typeof(temp_res)
	area_receiver.add_signal("health", [{ "name": "health", "type": temp_type_int }])
	area_receiver.connect("health", receive)

func receive(health_transmision:HealthTransmision)->void:
	health_transmision.apply(damage_receiver.health_resource)
