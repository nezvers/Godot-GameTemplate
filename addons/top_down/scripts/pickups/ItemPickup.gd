class_name ItemPickup
extends Node2D

@export var item_resource:ItemResource

@export var icon_sprite:Sprite2D

@export var data_transmitter:DataChannelTransmitter

@export var sound_resource:SoundResource

func _ready() -> void:
	if item_resource == null:
		return
	icon_sprite.texture = item_resource.icon
	
	var _transmission_resource:ItemTransmission = ItemTransmission.new()
	_transmission_resource.transmission_name = "item"
	_transmission_resource.item_resource = item_resource
	data_transmitter.transmission_resource = _transmission_resource
	
	data_transmitter.success.connect(_on_success, CONNECT_ONE_SHOT)
	

func _on_success()->void:
	data_transmitter.set_enabled(false)
	sound_resource.play_managed()
	## TODO: DO proper VFX
	queue_free()
