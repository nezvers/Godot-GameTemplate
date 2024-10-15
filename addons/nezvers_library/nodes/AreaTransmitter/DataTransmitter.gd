class_name DataTransmitter
extends Node

signal update_requested(transmission_resource:TransmissionResource)
signal success
signal failed
signal denied
signal try_again(receiver:AreaReceiver2D)

@export var enabled:bool = true
## If transmission errors with state TRY_AGAIN, try sending next physics frame
@export var try_next_frame:bool = true
## Data that will be transmitted
@export var transmission_resource:TransmissionResource
## Node that creates transmission connection
@export var area_transmitter:AreaTransmitter2D

func set_enabled(value:bool)->void:
	enabled = value

func _ready()->void:
	assert(transmission_resource != null)
	area_transmitter.area_entered.connect(on_area_entered)

func on_area_entered(area:Area2D)->void:
	if !(area is AreaReceiver2D):
		return
	send(area)

func send(receiver:AreaReceiver2D)->void:
	if !enabled:
		return
	var _transmission_resource:TransmissionResource = transmission_resource.duplicate()
	_transmission_resource.update_requested.connect(on_update_requested.bind(_transmission_resource))
	
	if _transmission_resource.send_transmission(receiver):
		on_success()
		return
	if _transmission_resource.state == TransmissionResource.ErrorType.FAILED:
		on_failed()
		return
	if _transmission_resource.state == TransmissionResource.ErrorType.DENIED:
		on_denied()
		return
	if _transmission_resource.state == TransmissionResource.ErrorType.TRY_AGAIN:
		# If this is called from next frame the calling signal connection is stil active.
		# By deffering a function call, the signal connection wont be active.
		on_try_again.call_deferred(receiver)
		return

## Call transmission next physics frame
func on_try_again(receiver:AreaReceiver2D)->void:
	try_again.emit(receiver)
	if try_next_frame:
		on_try_next_frame(receiver)

func on_try_next_frame(receiver:AreaReceiver2D)->void:
	get_tree().physics_frame.connect(test_receiver.bind(receiver), CONNECT_ONE_SHOT)

func test_receiver(receiver:AreaReceiver2D)->void:
	var overlapping_areas:Array[Area2D] = area_transmitter.get_overlapping_areas()
	if overlapping_areas.has(receiver):
		send(receiver)

## Give notification to other nodes
func on_success()->void:
	success.emit()

## Give notification to other nodes
func on_failed()->void:
	failed.emit()

## Give notification to other nodes
func on_denied()->void:
	denied.emit()

## Resource requests a need to be updated
func on_update_requested(transmission_resource:TransmissionResource)->void:
	update_requested.emit(transmission_resource)
