class_name DamageResource
extends SaveableResource

signal received_report(damage_data:DamageDataResource)
signal received_damage(damage_data:DamageDataResource)
signal can_receive_changed

@export var can_receive_damage:bool = true

var owner:Node

func set_can_receive_damage(value:bool)->void:
	can_receive_damage = value
	can_receive_changed.emit()

func report(damage_data:DamageDataResource)->void:
	received_report.emit(damage_data)

func receive(damage_data:DamageDataResource)->void:
	received_damage.emit(damage_data)
