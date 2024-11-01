## WARNING: Seems to be broken. Sub-resources are failing to load or something.
## Load resources with built in threaded loading
## Use this as hub for loading resources
extends Node

var callbacks: Dictionary
var load_list:Array[String]

func _ready()->void:
	set_process(false)

func _state_check()->void:
	set_process(!load_list.is_empty())

func _process(_delta:float)->void:
	for path in load_list:
		_process_status(path)

func _process_status(path:String)->void:
	var _status: = ResourceLoader.load_threaded_get_status(path)
	if _status == ResourceLoader.THREAD_LOAD_LOADED:
		_load_done(path)
	elif _status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	else:
		_load_failed(path)

func start_load(path:String, callable:Callable)->void:
	load_list.append(path)
	callbacks[path] = callable
	if path.is_empty():
		printerr("Loader [ERROR]: file path is empty ")
		_load_failed(path)
		return
	if !FileAccess.file_exists(path):
		printerr("Loader [ERROR]: file doesn't exist - ", path)
		_load_failed(path)
		return
	if ResourceLoader.load_threaded_request(path, "PackedScene", true, ResourceLoader.CACHE_MODE_REUSE):
		print("SceneLoader [ERROR]: start load failed")
		_load_failed(path)
		return
	_state_check()

func _load_done(path:String)->void:
	var _resource:Resource = ResourceLoader.load_threaded_get(path)
	if _resource == null:
		print("SceneLoader [ERROR]: Failed thredead load. Atempt regular load")
		_resource = ResourceLoader.load(path)
		if _resource == null:
			print("SceneLoader [ERROR]: Failed regular load")
	callbacks[path].call(_resource)
	load_list.erase(path)
	callbacks.erase(path)
	_state_check()

func _load_failed(path:String)->void:
	print("SceneLoader [ERROR]: Load failed - " + path)
	callbacks[path].call(null)
	load_list.erase(path)
	callbacks.erase(path)
	_state_check()
