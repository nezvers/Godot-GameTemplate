class_name DamageReceiver
extends Node

signal received_damage(damage:DamageResource)

@export var area_receiver:AreaReceiver2D
@export var health_resource:HealthResource
## Can't be damaged this time after taking a damage
@export var damage_cooldown:float = 0.0
## Node reported in DamageResource
@export var receiver_owner:Node

var last_time:float


func _ready()->void:
	health_resource.reset()
	var temp_res: = DamageResource.new()
	var damage_type_int:int = typeof(temp_res)
	area_receiver.add_signal("damage", [{ "name": "damage", "type": damage_type_int }])
	area_receiver.connect("damage", receive_damage)

func receive_damage(damage_resource:DamageResource)->void:
	if health_resource.is_dead:
		return
	var time:float = Time.get_ticks_msec() * 0.001
	if last_time + damage_cooldown > time:
		return
	last_time = time
	health_resource.take_damage(damage_resource)
	received_damage.emit(damage_resource)
	damage_resource.report_damage_data(receiver_owner)
