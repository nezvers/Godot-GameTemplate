class_name ThreadUtility
extends Node

## Load next scene from path using a thread
static func change_scene(path:String, scene_tree:SceneTree)->void:
	# create thread function to load and instantiate a scene, then pass it for scene swapping
	var _tread_load:Callable = func (path:String, callback:Callable, thread:Thread)->PackedScene:
		var _next_scene:Resource = load(path)
		assert(_next_scene != null)
		callback.call_deferred(_next_scene)
		
		# Thread will finnish itself on main thread using call_deffered.
		thread.wait_to_finish.call_deferred()
		return
	
	# Callback function for main thread to swap scenes
	var _change_scene:Callable = func (next_scene:PackedScene, scene_tree:SceneTree)->void:
		if scene_tree.current_scene != null:
			scene_tree.set_meta("current_scene", scene_tree.current_scene)
		var _current_scene:Node = scene_tree.get_meta("current_scene")
		
		scene_tree.root.remove_child(_current_scene)
		_current_scene.queue_free()
		
		var _scene:Node = next_scene.instantiate()
		scene_tree.root.add_child.call_deferred(_scene)
		scene_tree.set_meta("current_scene", _scene)
	
	# Temporary thread that will shut down itself in the thread function
	var _thread:Thread = Thread.new()
	_thread.start(_tread_load.bind(path, _change_scene.bind(scene_tree), _thread))
