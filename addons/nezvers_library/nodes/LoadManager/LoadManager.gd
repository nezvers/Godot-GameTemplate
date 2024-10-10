## Load resources with built in threaded loading
## Use this as hub for loading resources
extends Node

var callbacks: Dictionary
var load_list:Array[String]

func _ready()->void:
	set_process(false)

func state_check()->void:
	set_process(!load_list.is_empty())

func _process(_delta:float)->void:
	for path in load_list:
		var status: = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			load_done(path)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			load_failed(path)

func load_start(path:String, callable:Callable)->void:
	if path.is_empty():
		printerr("Loader [ERROR]: file path is empty ")
		return
	if !FileAccess.file_exists(path):
		printerr("Loader [ERROR]: file doesn't exist - ", path)
		return
	if ResourceLoader.load_threaded_request(path, "PackedScene", false, ResourceLoader.CACHE_MODE_IGNORE_DEEP):
		print("SceneLoader: start load failed")
		state_check()
		return
	load_list.append(path)
	callbacks[path] = callable
	state_check()

func load_done(path:String)->void:
	var scene:Resource = ResourceLoader.load_threaded_get(path)
	if scene == null:
		print("SceneLoader: Failed thredead load. Atempt regular load")
		scene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if scene == null:
			print("SceneLoader: Failed regular load")
	callbacks[path].call(scene)
	load_list.erase(path)
	callbacks.erase(path)
	state_check()

func load_failed(path:String)->void:
	callbacks[path].call(null)
	load_list.erase(path)
	callbacks.erase(path)
	print("SceneLoader: Load failed - " + path)
	state_check()
