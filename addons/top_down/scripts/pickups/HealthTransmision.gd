class_name HealthTransmision
extends TransmissionResource

@export var value:float

func set_value(_value:float)->void:
	value = _value
	updated.emit()

func apply(health_resource:HealthResource)->void:
	if health_resource.is_full() || health_resource.is_dead:
		return
	health_resource.add_hp(value)
	
	consume()
