# Loads a scene in the background using a seperate thread and a queue.
# Foreach new scene there will be an instance of ResourceInteractiveLoader
# that will raise an on_scene_loaded event once the scene has been loaded.
# Hooking the on_progress event will give you the current progress of any
# scene that is being processed in realtime. The loader also uses caching
# to avoid duplicate loading of scenes and it will prevent loading the
# same scene multiple times concurrently.
# 
# Sample usage:
#
# # Copy & Paste this script and create and AutoLoad for it, then on your world
# # manager copy & paste this snippet, make sure to replace the load_scene with 
# # a scene that exists in your project
#
#func _ready():
#	SceneLoader.connect("on_scene_loaded", self, "do_scene_loaded")
#	SceneLoader.load_scene("res://myscene.tscn", { hii = "cool" })
#
#func do_scene_loaded(scene):
#	# You can hook the instance name to run your specific per scene logic
#	# Example: parse the name for a substring such as "ITEM_" and then
#	# run your item specific logic
#	print(scene.path)
#	print(scene.instance.name)
#	print(scene.props.hii)
# 
#
# Author: @November_Dev
#

extends Node

var thread
var scene_queue = {}
var file = File.new()
var cache = {}
var awaiters = []

signal on_progress
signal on_scene_loaded

func _ready()->void:
	thread = Thread.new()
	thread.start(self, "_thread_runner", null)

func _thread_runner(o)->void:
	while true:
		OS.delay_msec(5)
		
		if scene_queue.size() > 0:
			for i in scene_queue:
				var err = scene_queue[i].loader.poll()
				call_deferred("emit_signal", "on_progress", scene_queue[i].path, scene_queue[i].loader.get_stage_count(), scene_queue[i].loader.get_stage())
				
				if err == ERR_FILE_EOF:
					scene_queue[i].loader = scene_queue[i].loader.get_resource()
					scene_queue[i].instance = scene_queue[i].loader.instance()
					cache[scene_queue[i].path] = scene_queue[i]
					call_deferred("emit_signal", "on_scene_loaded", scene_queue[i])
					scene_queue.erase(scene_queue[i].path)
				elif err != OK:
					print("Failed to load: " + scene_queue[i].path)
					scene_queue.erase(scene_queue[i].path)
		
		for awaiter in awaiters:
			if cache.has(awaiter.path):
				if awaiter.path == cache[awaiter.path].path:
					awaiter.loader = cache[awaiter.path].loader
					awaiter.instance = cache[awaiter.path].instance.duplicate()
					call_deferred("emit_signal", "on_scene_loaded", awaiter)
					awaiters.remove(awaiters.find(awaiter))

func load_scene(path:String, props = null)->void:
	if !file.file_exists(path):
		print("File does not exist: " + path)
		return
	
	if cache.has(path):
		call_deferred("emit_signal", "on_scene_loaded", { path = path, loader = cache[path].loader, instance = cache[path].instance.duplicate(), props = props })
		return
	
	if !scene_queue.has(path):
		scene_queue[path] = { path = path, loader = ResourceLoader.load_interactive(path), instance = null, props = props }
	else:
		awaiters.push_back({ path = path, loader = null, instance = null, props = props })

func is_loading_scene(path)->bool:
	return scene_queue.has(path)

func clear_cache()->void:
	for item in cache:
		item.instance.queue_free()
	cache = {}
