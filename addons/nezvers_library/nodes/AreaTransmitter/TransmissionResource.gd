class_name TransmissionResource
extends ValueResource

enum ErrorType {NONE = -1, CONSUMED = 0, TRY_AGAIN, FAILED}

@export var transmission_name:StringName
@export var state:ErrorType = ErrorType.NONE

func send_transmission(receiver:AreaReceiver2D)->ErrorType:
	## Receiving end must call either one 
	receiver.emit_signal(transmission_name, self)
	
	# TODO: if signal exists use this assert
	#assert(state != ErrorType.NONE)
	return state

func consume()->void:
	state = ErrorType.CONSUMED

func try_again()->void:
	state = ErrorType.TRY_AGAIN

func failed()->void:
	state = ErrorType.FAILED
