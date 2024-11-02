class_name ThreadUtility
extends Node

## Load next scene from path using a thread
static func load_resource(path:String, receive_callback:Callable)->void:
	# create thread function to load resource and shut down the tread
	var _tread_load:Callable = func (path:String, callback:Callable, thread:Thread)->PackedScene:
		var _resource:Resource = load(path)
		callback.call_deferred(_resource)
		
		# Thread will finnish itself on main thread using call_deffered.
		thread.wait_to_finish.call_deferred()
		return
	
	# Temporary thread that will shut down itself in the thread function
	var _thread:Thread = Thread.new()
	_thread.start(_tread_load.bind(path, receive_callback, _thread))
