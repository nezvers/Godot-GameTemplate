class_name SharedResource
extends Resource

## Notification signal when reference has been changed
signal updated

@export var resource:Resource : set = set_resource

var listeners:Array[Callable]

func set_resource(value:Resource)->void:
	resource = value
	for callback in listeners:
		callback.call()
	updated.emit()

func listen(inst:Node, callback:Callable)->void:
	listeners.append(callback)
	inst.tree_exited.connect(remove_callback.bind(callback))
	callback.call()

func remove_callback(callback:Callable)->void:
	listeners.erase(callback)

func get_save_file_path()->String:
	return "user://" + resource_name + "_resource.tres"

func save_resource()->void:
	print("Shared resource saved level: ", resource.selected)
	if ResourceSaver.save(resource, get_save_file_path()):
		print(resource_name, ": failed to save")

func load_resource()->void:
	if !FileAccess.file_exists(get_save_file_path()):
		print(resource_name, ": no savefile")
		return
	var data:Resource = ResourceLoader.load(get_save_file_path(), "", ResourceLoader.CACHE_MODE_REPLACE)
	if data == null:
		print(resource_name, ": failed to load")
		return
	set_resource(data)
