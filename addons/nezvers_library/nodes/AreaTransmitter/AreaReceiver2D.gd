class_name AreaReceiver2D
extends Area2D


func add_signal(signal_name:StringName, argument_info:Array[Dictionary])->void:
	if has_user_signal(signal_name):
		return
	add_user_signal(signal_name, argument_info)


## Receive any kind of data will get transmitted through channel_id signal
func receive(signal_name:StringName, data:Variant)->void:
	get(signal_name).emit(data)
