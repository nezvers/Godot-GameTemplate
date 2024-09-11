class_name DamageSource
extends Area2D

signal hit_solid
signal hit

@export var damage_resource:DamageResource
@export var check_solid:bool = true


func _ready()->void:
	area_entered.connect(on_area_entered)
	if check_solid:
		body_entered.connect(on_body_entered)


## Transfer damage to a detected Area2D
func on_area_entered(area:Area2D)->void:
	if !(area is DamageReceiver):
		return
	# Call before passign resource, for other code to do update manipulations 
	hit.emit()
	(area as DamageReceiver).take_damage(damage_resource)

func on_body_entered(body:Node2D)->void:
	if body is TileMapLayer || body is TileMap:
		hit_solid.emit()
		return
