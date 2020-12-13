class_name ResourceAsyncLoader  #Godot 3.2.2

#USE IT LIKE THIS
#var loader = ResourceAsyncLoader_GT.new()
#var list = ["res://icon.png"]
#var resources = yield(loader.load_start( list ), "completed")

signal done

var thread: = Thread.new()
var mutex: = Mutex.new()

var can_async:bool = OS.can_use_threads()

func split_work(work:int, workers:int, vector:Array)->Array:
  var step = int(work / workers)
  var remainder = work % workers
  var return_vector = []
  var begin = 0
  var end = 0
  for i in range(workers):
    end += step
    if (remainder != 0):
      end += 1
      remainder -= 1
    return_vector.append(vector.slice(begin, end-1, 1))
    begin = end
  return return_vector

func load_start(resource_list:Array)->Array:
  var resources_in = resource_list.duplicate()
  var out: = []
  if can_async:
    var n_threads = min(resources_in.size(), OS.get_processor_count())
    var threads = []
    for i in range(n_threads):
      threads.append(Thread.new())
      
    resources_in = split_work(resources_in.size(), n_threads, resources_in)
    for i in range(n_threads):
      threads[i].start(self, 'threaded_load', resources_in[i])
      
    for i in range(n_threads):
      out += yield(self, "done")
      
    for i in range(n_threads):
      threads[i].wait_to_finish()
  else:
    out += regular_load(resources_in)
  return out
  
func threaded_load(resources_in:Array)->void:
  var resources_out: = []
  for res_in in resources_in:
    resources_out.append(load(res_in))
  mutex.lock()
  call_deferred('emit_signal', 'done', resources_out)
  mutex.unlock()
      
func regular_load(resources_in:Array)->Array:
  var resources_out: = []
  for res_in in resources_in:
    resources_out.append(load(res_in))
  return resources_out