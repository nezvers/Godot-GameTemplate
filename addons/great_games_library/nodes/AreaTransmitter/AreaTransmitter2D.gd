class_name AreaTransmitter2D
extends Area2D

@export var enabled:bool = true

## Collect send callbacks for all child DataChannelTransmitter
var send_list:Array[Callable]

func set_enabled(value:bool)->void:
	enabled = value

func _ready()->void:
	# BUG: https://github.com/godotengine/godot/issues/17238
	#set_monitorable.call_deferred(false)
	process_mode = PROCESS_MODE_ALWAYS
	area_entered.connect(_on_area_entered)
	
	for child:Node in get_children():
		if !(child is DataChannelTransmitter):
			continue
		var data_transmitter:DataChannelTransmitter = child as DataChannelTransmitter
		send_list.append(data_transmitter.send)
		data_transmitter.check_receiver.connect(_on_check_receiver.bind(data_transmitter))

## Area2D version to check if receiver still overlaps.
func _on_check_receiver(receiver:AreaReceiver2D, data_transmitter:DataChannelTransmitter)->void:
	var overlap_list:Array = get_overlapping_areas()
	if !overlap_list.has(receiver):
		return
	data_transmitter.send(receiver)

## Area2D version to trigger data transmission
func _on_area_entered(area:Area2D)->void:
	if !(area is AreaReceiver2D):
		return
	for _callback:Callable in send_list:
		_callback.call(area as AreaReceiver2D)
