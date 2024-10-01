class_name EffectTransmitter
extends Node

signal consumed

# TODO: maybe add enabled to manage connections

@export var area_transmitter:AreaTransmitter2D
@export var effect_transmission:EffectTransmision

func _ready()->void:
	assert(effect_transmission != null)
	area_transmitter.area_entered.connect(on_area_entered)

func on_area_entered(area:Area2D)->void:
	if !(area is AreaReceiver2D):
		return
	var effect_dup:EffectTransmision = effect_transmission.duplicate()
	effect_dup.consumed.connect(on_consumed, CONNECT_ONE_SHOT)
	(area as AreaReceiver2D).emit_signal(effect_dup.effect_signal, effect_dup)

func on_consumed()->void:
	consumed.emit()
