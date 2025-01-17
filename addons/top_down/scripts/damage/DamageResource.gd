class_name DamageResource
extends SaveableResource

signal report_damage(damage_data:DamageDataResource)
signal received_damage(damage_data:DamageDataResource)
signal received_damage_points(points:float, is_critical:bool)
signal store_status(status_effect:DamageStatusResource)

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
	report_damage.emit(damage_data)

func receive(damage_data:DamageDataResource)->void:
	received_damage.emit(damage_data)
	receive_points(damage_data.total_damage, damage_data.is_critical)

func receive_points(points:float, is_critical:bool = false)->void:
	received_damage_points.emit(points, is_critical)

func add_status_effect(status_effect:DamageStatusResource)->void:
	store_status.emit(status_effect)
