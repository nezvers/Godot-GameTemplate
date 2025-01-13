## Handles received transmission preliminary processing on receivers behalf for a certain transmission channel.
class_name DataChannelReceiver
extends Node

## Emited when transmission is granted access
signal transmission_received(transmission_resource:TransmissionResource)

## Emitted to give option to validate transmission. transmission_resource.set_valid(true)
signal transmission_validate(transmission_resource:TransmissionResource)

@export var enabled:bool = true

## Sets TransmissionResource state to TRY_AGAIN next physics frame
@export var bypass:bool = false

## Will receive transmissions with this name. Only one receiver for each name. 
@export var transmission_name:StringName

## Node used to create receiver chain
@export var area_receiver:AreaReceiver2D

## Resource node holds HealthResource
@export var resource_node:ResourceNode

## If enabled is false, an incoming transmission will fail.
func set_enabled(value:bool)->void:
	enabled = value

## If bypass is true, an incoming transmission will try again next physics frame.
func set_bypass(value:bool)->void:
	bypass = value

func _ready()->void:
	# creates a signal with it's argument signature
	area_receiver.add_receiver(transmission_name, receive)

func receive(transmission_resource:TransmissionResource)->void:
	if !enabled:
		transmission_resource.failed()
		return
	if bypass:
		transmission_resource.try_again()
		return
	
	# option to check incomming data, like damage and modify it before processing it
	transmission_validate.emit(transmission_resource)
	if !transmission_resource.valid:
		transmission_resource.denied()
		return
	
	transmission_resource.process(resource_node)
	transmission_received.emit(transmission_resource)
