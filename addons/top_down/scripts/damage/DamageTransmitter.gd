class_name DamageTransmitter
extends Node

signal hit

@export var area_transmitter:AreaTransmitter2D
@export var damage_resource:DamageResource


func _ready()->void:
	area_transmitter.area_entered.connect(on_area_entered)


## Transfer damage to a detected Area2D
func on_area_entered(area:Area2D)->void:
	if !(area is AreaReceiver2D):
		return
	# Call before passign resource, for other code to do update manipulations 
	hit.emit()
	(area as AreaReceiver2D).emit_signal("damage", damage_resource)
