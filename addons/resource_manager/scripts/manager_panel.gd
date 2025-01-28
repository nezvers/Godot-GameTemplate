@tool
class_name ResourceManagerPanel
extends Control


@export var list_parent:Control

@export var directory_entry:LineEdit

@export var class_entry:LineEdit

@export var search_entry:LineEdit

var root_directory:String

var search_name:String

var resource_class:String

var resource_array:Array[Resource]

var resource_dictionary:Dictionary

var is_tool:bool

const RESOURCE_PROPERTY = preload("res://addons/resource_manager/scenes/resource_property.tscn")

func _ready()->void:
	if !is_tool:
		return
	directory_entry.text_submitted.connect(_set_root_directory)
	print("Manager ready")
	
	resource_class = class_entry.text
	class_entry.text_submitted.connect(_set_class_filter)
	
	search_name = search_entry.text
	search_entry.text_changed.connect(_search_match)
	
	_set_root_directory(directory_entry.text)

func update_resources()->void:
	_set_root_directory(directory_entry.text)

func _set_root_directory(value:String)->void:
	print("New directory: ", value)
	root_directory = value
	resource_array.clear()
	resource_dictionary.clear()
	
	# Remove curent list
	for _child:Node in list_parent.get_children():
		list_parent.remove_child(_child)
		_child.queue_free()
	
	if root_directory.is_empty():
		## TODO: Cleanup
		return
	
	if !DirAccess.dir_exists_absolute(root_directory):
		## TODO: Cleanup
		return
	
	_scan_directory_recursively(root_directory)
	_search_match(search_name)

func _scan_directory_recursively(path:String)->void:
	#print("Scanning directory: ", path)
	var _current_directory: = DirAccess.open(path)
	if _current_directory == null:
		## TODO: Cleanup
		return
	
	var _file_list:PackedStringArray = _current_directory.get_files()
	#print("Files found: ", _file_list)
	
	var _last_index:int = _file_list.size() -1
	for i:int in _file_list.size():
		var _file_name:String = _file_list[i]
		if _file_name.get_extension() != "tres":
			#_file_name.erase(_last_index - i)
			continue
		_load_resource(path + _file_name)
	
	var _sub_dir_list:PackedStringArray = _current_directory.get_directories()
	for _dir:String in _sub_dir_list:
		_scan_directory_recursively(path + _dir + "/")


func _load_resource(path:String)->void:
	var _file_name:String = path.get_file().get_basename()
	#print("Loading resource: ", _file_name)
	
	var _resource:Resource = ResourceLoader.load(path)
	if _resource == null:
		return
	if !resource_class.is_empty():
		## TODO: is_class is stupidly limited to only built-in, need beter way to include all parent classes
		var _script:Script = _resource.get_script()
		if _script != null:
			var _script_class:String = _script.get_global_name()
			if _script_class.is_empty():
				return
			if _script_class != resource_class:
				return
		elif _resource.is_class(resource_class):
			return
	resource_array.append(_resource)
	
	resource_dictionary[_file_name] = _resource
	
	if !_resource.resource_name.is_empty():
		resource_dictionary[_resource.resource_name] = _resource


func _add_item(_resource:Resource)->void:
	if _resource == null:
		return
	
	var _property_editor:ResourcePropertyEditor = RESOURCE_PROPERTY.instantiate()
	_property_editor.setup(null, _resource, "")
	
	_property_editor.editor_resource_picker.editable = true
	list_parent.add_child(_property_editor)
	if !resource_class.is_empty():
		_property_editor.editor_resource_picker.base_type = resource_class

func _search_match(value:String)->void:
	search_name = value
	#print("Searching value: ", search_name)
	
	# Remove curent list
	for _child:Node in list_parent.get_children():
		list_parent.remove_child(_child)
		_child.queue_free()
	
	#Show all
	if search_name.is_empty():
		for _resource:Resource in resource_array:
			_add_item(_resource)
		return
	
	# Fuzzy search
	var _keys:Array = resource_dictionary.keys()
	var _filter_callback:Callable = func(key:String)->bool:
		return key.contains(value)
	_keys = _keys.filter(_filter_callback)
	
	
	# skipp duplicate entries for resource_name and rsource_path
	var _unique_array:Array[Resource]
	for _key:String in _keys:
		var _resource:Resource = resource_dictionary[_key]
		if _unique_array.has(_resource):
			continue
		_unique_array.append(_resource)
	
	for _resource:Resource in _unique_array:
		_add_item(_resource)

func _set_class_filter(value:String)->void:
	resource_class = value
	update_resources()
