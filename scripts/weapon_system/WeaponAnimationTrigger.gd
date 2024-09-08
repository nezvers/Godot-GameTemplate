class_name WeaponAnimationTrigger
extends Node

@export var weapon:Weapon
@export var animation_player:AnimationPlayer
@export var animation_name:StringName

func _ready()->void:
	if animation_player == null || animation_name.is_empty():
		return
	if !animation_player.has_animation(animation_name):
		printerr(owner.name, " AnimationTrigger [ERROR]: AnimationPlayer don't have animation - ", animation_name)
		return
	weapon.projectile_created.connect(play)

func play()->void:
	animation_player.stop()
	animation_player.play(animation_name)
