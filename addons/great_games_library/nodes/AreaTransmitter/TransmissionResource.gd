class_name TransmissionResource
extends ValueResource

## Notifies a need to be updated
signal update_requested

## Value for error from transmission receiver
enum ErrorType {
	## Default value
	NONE = -1,
	## Transmission processed successfully
	SUCCESS = 0, 
	## Try transmission next physics frame
	TRY_AGAIN, 
	## Transmission processing was denied
	DENIED,
	## Transmission process was denied
	FAILED}

@export_group("TransmissionResource")

## Used as transmission channel to match which receiver needs to process it
@export var transmission_name:StringName

## State of transmission process
@export var state:ErrorType = ErrorType.NONE

## Receiving end might decide that transmission is invalid and processing will be cancelled.
@export var valid:bool = true

## 
func send_transmission(receiver:AreaReceiver2D)->bool:
	assert( !transmission_name.is_empty() )
	## Receiving end must call either one 
	receiver.receive(self)
	
	# TODO: if signal exists use this assert
	#assert(state != ErrorType.NONE)
	return state == ErrorType.SUCCESS

func success()->void:
	state = ErrorType.SUCCESS

func try_again()->void:
	state = ErrorType.TRY_AGAIN

func failed()->void:
	state = ErrorType.FAILED

func denied()->void:
	state = ErrorType.DENIED

func invalid()->void:
	valid = false

## Receiver need to provide a reference to a ResourceNode
## Override this function with specific use.
## Should result with a state change
func process(resource_node:ResourceNode)->void:
	pass
