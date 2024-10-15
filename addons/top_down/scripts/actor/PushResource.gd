## Signals an intention to be pushed
class_name PushResource
extends SaveableResource

signal impulse_event(impulse:Vector2)

func add_impulse(impulse:Vector2)->void:
	impulse_event.emit(impulse)
