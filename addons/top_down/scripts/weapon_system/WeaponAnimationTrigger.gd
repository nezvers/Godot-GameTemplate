class_name WeaponAnimationTrigger
extends Node

@export var weapon_trigger:WeaponTrigger
@export var animation_player:AnimationPlayer
@export var animation_list:Array[StringName]

var animation_index:int

func _ready()->void:
	if animation_player == null || animation_list.is_empty():
		return
	weapon_trigger.shoot_event.connect(play)

func play()->void:
	animation_player.stop()
	animation_player.play(animation_list[animation_index])
	animation_index = (animation_index +1) % animation_list.size()
