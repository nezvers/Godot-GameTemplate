class_name AreaReceiver2D
extends Area2D

## transmission name used as key to callback that validates that transmission
var callbacks:Dictionary

func _ready()->void:
	process_mode = PROCESS_MODE_ALWAYS
	monitoring = false


## Receive any kind of data will get transmitted through channel_id signal
func receive(transmision_resource:TransmissionResource)->void:
	if callbacks.has(transmision_resource.transmission_name):
		callbacks[transmision_resource.transmission_name].call(transmision_resource)
		return
	transmision_resource.failed()

## Registers processor for transmissions
func add_receiver(transmission_name:StringName, callback:Callable)->void:
	callbacks[transmission_name] = callback
