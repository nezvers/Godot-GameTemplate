class_name ResourceAsyncLoader	#Godot 3.2.2

#USE IT LIKE THIS
#var loader = ResourceAsyncLoader.new()
#var list = ["res://icon.png"]
#var resources = yield(loader.load_start( list ), "completed")

signal done

var thread: = Thread.new()
var mutex: = Mutex.new()

var can_async:bool = !Settings.HTML5 and (OS.get_processor_count() > 1)

func load_start(resource_list:Array)->Array:
	var resources_in = resource_list.duplicate()
	var out: = []
	if can_async:
		thread.start(threaded_load.bind(resources_in))
		out = await self.done
		thread.wait_to_finish()
	else:
		out = regular_load(resources_in)
	return out

func threaded_load(resources_in:Array)->void:
	var resources_out: = []
	for res_in in resources_in:
		mutex.lock()
		resources_out.append(load(res_in))
		mutex.unlock()
	call_deferred('emit_signal', 'done', resources_out)

func regular_load(resources_in:Array)->Array:
	var resources_out: = []
	for res_in in resources_in:
		resources_out.append(load(res_in))
	return resources_out
