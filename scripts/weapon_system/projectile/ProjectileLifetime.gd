class_name ProjectileLifetime
extends Node

@export var time:float = 1.0
@export var projectile:Projectile2D

func _ready()->void:
	if !(time > 0.0):
		return
	var tween:Tween = create_tween()
	tween.tween_callback(on_timeout).set_delay(time)

func on_timeout()->void:
	projectile.prepare_exit()
