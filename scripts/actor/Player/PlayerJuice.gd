class_name PlayerJuice
extends Node

@export var damage_receiver:DamageReceiver
@export var screen_flash_command:CommandNodeResource

func _ready()->void:
	damage_receiver.health_resource.damaged.connect(on_damaged)

func on_damaged()->void:
	assert(screen_flash_command.node != null, "reference is not set")
	screen_flash_command.command("play", ["white_flash"])
