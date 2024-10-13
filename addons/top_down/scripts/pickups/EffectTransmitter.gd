class_name EffectTransmitter
extends Node

signal consumed

# TODO: maybe add enabled to manage connections

@export var area_transmitter:AreaTransmitter2D
@export var effect_transmission:TransmissionResource

func _ready()->void:
	assert(effect_transmission != null)
	area_transmitter.area_entered.connect(on_area_entered)

func on_area_entered(area:Area2D)->void:
	if !(area is AreaReceiver2D):
		return
	send(area)

func send(receiver:AreaReceiver2D)->void:
	var effect_dup:TransmissionResource = effect_transmission.duplicate()
	var err:TransmissionResource.ErrorType = effect_dup.send_transmission(receiver)
	
	# TODO: maybe situations when need to handle FAILED and NONE
	if err == TransmissionResource.ErrorType.CONSUMED:
		on_consumed()
		return
	if err == TransmissionResource.ErrorType.TRY_AGAIN:
		# If this is called from next frame the calling signal connection is stil active.
		# Need to delay somewhere after this function call.
		try_again.call_deferred(receiver)
		return

## Call transmission next physics frame
func try_again(receiver:AreaReceiver2D)->void:
	get_tree().physics_frame.connect(test_receiver.bind(receiver), CONNECT_ONE_SHOT)

func test_receiver(receiver:AreaReceiver2D)->void:
	var overlapping_areas:Array[Area2D] = area_transmitter.get_overlapping_areas()
	if overlapping_areas.has(receiver):
		send(receiver)

## Give notification to other nodes
func on_consumed()->void:
	consumed.emit()
