## Base class to create saveable Resource
class_name SaveableResource
extends Resource

signal resource_saved
signal resource_loaded

@export_group("SaveableResource")

## Allows to detect older save data information
@export var version:int

## Isn't saved and resets instead of loading
@export var not_saved:bool

## Keep track if loading have happened and without forcing it won't reload.
var is_loaded:bool = false

## Type of saving save files
enum SaveType {FILE, STEAM}

## Class variable for saving behaviour
static var save_type: = SaveType.FILE

var temporary_data:SaveableResource
var is_temporary:bool


static func set_save_type(value:SaveType)->void:
	save_type = value

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

## Saves current state.
## If SaveState is temporary it uses temporary data.
func save_resource()->void:
	if not_saved:
		return
	if is_temporary:
		save_temp()
		return
	
	if save_type == SaveType.FILE:
		## TODO: use error codes for return values
		if _save_resource_file() > 0:
			return
	elif save_type == SaveType.STEAM:
		## TODO: use steam integration
		if _save_resource_file() > 0:
			return
	resource_saved.emit()

## Loads and sets last saved state.
## If SaveState is temporary it uses temporary data.
## If it is already loaded once without force_load it won't do loading.
func load_resource(force_load:bool = false)->void:
	if is_loaded && !force_load:
		return
	is_loaded = true
	
	if not_saved:
		reset_resource()
		return
	if is_temporary:
		load_temp()
		return
	
	var data:SaveableResource
	if save_type == SaveType.FILE:
		data = _load_resource_file()
	elif save_type == SaveType.STEAM:
		## TODO: use Steam integration
		data = _load_resource_file()
	
	if data == null:
		print("SaveableResource [INFO]: save file didn't load, resetting - ", resource_name)
		reset_resource()
		return
	
	prepare_load(data)
	resource_loaded.emit()

func delete_resource()->void:
	if save_type == SaveType.FILE:
		_delete_resource_file()
	elif save_type == SaveType.STEAM:
		# TODO: use Steam integration
		_delete_resource_file()

func _save_resource_file()->int:
	var data:SaveableResource = prepare_save()
	var path: = get_save_file_path()
	if ResourceSaver.save(data, path):
		print("ResourceSaver [INFO]: failed to save file", resource_name)
		return 1
	return 0

func _load_resource_file()->SaveableResource:
	var path: = get_save_file_path()
	if !FileAccess.file_exists(path):
		print("SaveableResource [INFO]: no save file - ", resource_name)
		return null
	return ResourceLoader.load(path)

func _delete_resource_file()->void:
	var path: = get_save_file_path()
	if !FileAccess.file_exists(path):
		pass
	DirAccess.remove_absolute(path)
