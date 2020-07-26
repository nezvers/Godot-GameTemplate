extends Node

signal scene_loaded

var file
var thread
var mutex
var semaphore
var resource
var exit_thread = false
var props = {} #Extra info passed along loading request

func _ready()->void:
	if Settings.HTML5: #Doesn't work on HTML5
		return
	file = File.new()
	thread = Thread.new()
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	thread.start(self, "thread_func")

func load_scene(path, instruction)->void:
	mutex.lock()
	if !file_check(path):
		print("File does not exist: " + path)
		return
	mutex.unlock()

	mutex.lock()
	props[path] = instruction
	resource = path
	mutex.unlock()

	semaphore.post()

func file_check(path)->bool:
	var result = false
	mutex.lock()
	result = file.file_exists(path)
	mutex.unlock()
	return result

func thread_func(_o=null)->void:
	while true: #Trap the function
		semaphore.wait()	#start the work when semaphote.post()

		mutex.lock()
		var should_exit = exit_thread # Protect with Mutex.

		if should_exit:
			break
		mutex.unlock()

		mutex.lock() #didn't feel like to do separate lock
		var scene = load(resource)
		call_deferred("emit_signal", "scene_loaded", {resource=scene, instructions = props[resource]})
		mutex.unlock()

func _exit_tree()->void: #even autoloaded script needs to do this or bricks on quiting
	if !Settings.HTML5:
		mutex.lock()
		exit_thread = true #this is checked in thread
		mutex.unlock()
	
		semaphore.post()	#give last resume to the function to see it neads to break
		thread.wait_to_finish()	#sync the threads
