class_name DamageResource
extends SaveableResource

signal received_report(damage_data:DamageDataResource)
signal received_damage(damage_data:DamageDataResource)
signal can_receive_changed

@export var can_receive_damage:bool = true

## Resistance value for each DamageType summed.
## Placed in an array for optimized value fetching.
## It is initialized and managed by DamageSetup Node.
var resistance_value_list:Array[float]

var owner:Node

func set_can_receive_damage(value:bool)->void:
	can_receive_damage = value
	can_receive_changed.emit()

func report(damage_data:DamageDataResource)->void:
	received_report.emit(damage_data)

func receive(damage_data:DamageDataResource)->void:
	received_damage.emit(damage_data)
