class_name ChangeSceneButton
extends Node

@export var button:Button
@export var scene_path:String

func _ready()->void:
	button.pressed.connect(pressed)

func pressed()->void:
	# Avoid triggering multiple times
	# Deffered because this function is called by that signal
	button.pressed.disconnect.call_deferred(pressed)
	
	# Apparently it's possible to use threads in this funny configuration
	var _thread:Thread = Thread.new()
	_thread.start(thread_load.bind(scene_path, on_loaded, _thread))

## Load next scene from path.
## Loaded scene will be passed to callback.
## Thread will finnish itself using call_deffered.
func thread_load(path:String, callback:Callable, thread:Thread)->PackedScene:
	var _resource:Resource = load(path)
	callback.call_deferred(_resource)
	thread.wait_to_finish.call_deferred()
	return

## Receives loaded scene and swaps active scene
func on_loaded(next_scene:PackedScene)->void:
	assert(next_scene != null)
	var _scene:Node = next_scene.instantiate()
	
	var _tree:SceneTree = get_tree()
	var _current_scene:Node = _tree.current_scene
	_tree.root.remove_child(_current_scene)
	_current_scene.queue_free()
	
	_tree.root.add_child(_scene)
	_tree.current_scene = _scene
