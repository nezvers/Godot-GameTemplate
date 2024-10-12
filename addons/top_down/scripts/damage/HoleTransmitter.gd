extends Node

@export var area_transmitter:AreaTransmitter2D

func _ready()->void:
	area_transmitter.area_entered.connect(on_area_entered)


## Transfer damage to a detected Area2D
func on_area_entered(area:Area2D)->void:
	if !(area is AreaReceiver2D):
		return
	
	(area as AreaReceiver2D).emit_signal("hole")
