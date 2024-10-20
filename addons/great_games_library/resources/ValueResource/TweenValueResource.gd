class_name TweenValueResource
extends ValueResource

var value:Tween : set = set_value

func set_value(_value:Tween)->void:
	# TODO: interupt with validate or override (clamp)
	value = _value
	updated.emit()
