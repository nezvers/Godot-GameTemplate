## Base class to create saveable Resource
class_name SaveableResource
extends Resource

signal resource_saved
signal resource_loaded

@export_group("SaveableResource")
## Allows to detect older save data information
@export var version:int
## Resets instead of loading and isn't saved
@export var not_saved:bool


enum SaveType {FILE, TEMP}
var save_state: = SaveType.FILE
var temporary_data:SaveableResource

func set_save_state(new_state:SaveType)->void:
	save_state = new_state

## Override for creating data Resource that will be saved with the ResourceSaver
func prepare_save()->Resource:
	return self.duplicate()

## Override to ad logic for reading loaded data and applying to current instance of the Resource
func prepare_load(_data:Resource)->void:
	pass

## Override function for resetting to default values
func reset_resource()->void:
	pass

func save_temp()->void:
	temporary_data = prepare_save()

func load_temp()->void:
	prepare_load(temporary_data)

func get_save_file_path()->String:
	if resource_name.is_empty():
		resource_name = resource_path.get_file().get_basename()
	return "user://" + resource_name + ".tres"

func save_resource()->void:
	if not_saved:
		return
	if save_state == SaveType.TEMP:
		save_temp()
		return
	
	var path: = get_save_file_path()
	var data:SaveableResource = prepare_save()
	if ResourceSaver.save(data, path):
		print(resource_name, ": failed to save")
		return
	resource_saved.emit()

func load_resource()->void:
	if not_saved:
		reset_resource()
		return
	if save_state == SaveType.TEMP:
		load_temp()
		return
	var path: = get_save_file_path()
	if !FileAccess.file_exists(path):
		print(resource_name, ": no savefile")
		reset_resource()
		return
	var data:SaveableResource = ResourceLoader.load(path)
	if data == null:
		print(resource_name, ": Save file didn't load")
		reset_resource()
		return
	
	prepare_load(data)
	resource_loaded.emit()

func delete_resource()->void:
	var path: = get_save_file_path()
	if !FileAccess.file_exists(path):
		pass
	DirAccess.remove_absolute(path)
