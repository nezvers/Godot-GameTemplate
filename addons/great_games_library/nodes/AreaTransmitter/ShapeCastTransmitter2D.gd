## ShapeCast version to test when needed
class_name ShapeCastTransmitter2D
extends ShapeCast2D

@export var exclude_list:Array[CollisionObject2D]

## Collect send callbacks for all child DataChannelTransmitter
var send_list:Array[Callable]

func _ready()->void:
	# BUG: https://github.com/godotengine/godot/issues/17238
	#set_monitorable.call_deferred(false)
	process_mode = PROCESS_MODE_ALWAYS
	enabled = false
	collide_with_areas = true
	collide_with_bodies = false
	
	for _body:CollisionObject2D in exclude_list:
		add_exception(_body)
	
	for child:Node in get_children():
		if !(child is DataChannelTransmitter):
			continue
		var data_transmitter:DataChannelTransmitter = child as DataChannelTransmitter
		send_list.append(data_transmitter.send)
		data_transmitter.check_receiver.connect(_on_check_receiver.bind(data_transmitter))

## Area2D version to check if receiver still overlaps.
func _on_check_receiver(receiver:AreaReceiver2D, data_transmitter:DataChannelTransmitter)->void:
	force_shapecast_update()
	for i:int in get_collision_count():
		if get_collider(i) == receiver:
			data_transmitter.send(receiver)
			return

## Area2D version of sending transmission
func check_transmission()->void:
	force_shapecast_update()
	for i:int in get_collision_count():
		var _collider:Object = get_collider(i)
		if !(_collider is AreaReceiver2D):
			continue
		for _callback:Callable in send_list:
			_callback.call(_collider as AreaReceiver2D)
