@tool extends Node

@export var new_button:Button

@export var create_button:Button

@export var setup_container:Control

@export var parent_reference_container:Control

@export var previous_container:Control

@export var parent_reference_menu:MenuButton

@export var directory_line_edit:LineEdit
@export var file_name_line_edit:LineEdit
@export var resource_name_line_edit:LineEdit
@export var scene_path_line_edit:LineEdit

@export var manager_panel:ResourceManagerPanel

enum StateType {NEW, SETUP}

var state:StateType = StateType.NEW

var parent_reference_resource_picker:EditorResourcePicker
var previous_resource_picker:EditorResourcePicker

var parent_reference_array:Array[ReferenceNodeResource] = [
	preload("res://addons/top_down/resources/RoomResources/floor_tilemap_reference.tres"),
	preload("res://addons/top_down/resources/RoomResources/obstacle_reference.tres"),
	preload("res://addons/top_down/resources/RoomResources/behind_reference.tres"),
	preload("res://addons/top_down/resources/RoomResources/ysort_reference.tres"),
	preload("res://addons/top_down/resources/RoomResources/front_reference.tres"),
]

func _set_state(new_state:StateType)->void:
	state = new_state
	
	new_button.visible = state == StateType.NEW
	previous_container.visible = state == StateType.NEW
	setup_container.visible = state == StateType.SETUP

func _ready()->void:
	if !manager_panel.is_tool:
		return
	_set_state(StateType.NEW)
	new_button.pressed.connect(_set_state.bind(StateType.SETUP))
	create_button.pressed.connect(_validate_setup)
	
	previous_resource_picker = EditorResourcePicker.new()
	previous_resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous_resource_picker.base_type = "InstanceResource"
	previous_container.add_child(previous_resource_picker)
	
	parent_reference_resource_picker = EditorResourcePicker.new()
	parent_reference_resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_reference_resource_picker.base_type = "ReferenceNodeResource"
	parent_reference_container.add_child(parent_reference_resource_picker)
	
	var _popup_menu:PopupMenu = parent_reference_menu.get_popup()
	_popup_menu.id_pressed.connect(_set_parent_reference)
	_popup_menu.add_item("Floor", 0)
	_popup_menu.add_item("Obstacles", 1)
	_popup_menu.add_item("Behind", 2)
	_popup_menu.add_item("Y-Sort", 3)
	_popup_menu.add_item("Front", 4)

func _set_parent_reference(index:int)->void:
	print("Chosen: ", index)
	parent_reference_resource_picker.edited_resource = parent_reference_array[index]

func _validate_setup()->void:
	if parent_reference_resource_picker.edited_resource == null:
		return
	if directory_line_edit.text.is_empty():
		return
	if file_name_line_edit.text.is_empty():
		return
	if resource_name_line_edit.text.is_empty():
		return
	if scene_path_line_edit.text.is_empty():
		return
	if !DirAccess.dir_exists_absolute(directory_line_edit.text):
		printerr("Directory doesn't exist - ", directory_line_edit.text)
		return
	if FileAccess.file_exists(scene_path_line_edit.text):
		printerr("Scene file doesn't exist - ", scene_path_line_edit.text)
		return
	
	if !file_name_line_edit.text.ends_with(".tres"):
		file_name_line_edit.text += ".tres"
	
	
	var _path:String = directory_line_edit.text + file_name_line_edit.text
	if FileAccess.file_exists(_path):
		printerr("File exists - ", _path)
		return
	
	var _new_resource: = InstanceResource.new()
	_new_resource.parent_reference_resource = parent_reference_resource_picker.edited_resource
	_new_resource.resource_name = resource_name_line_edit.text
	_new_resource.resource_path = _path
	var err:Error = ResourceSaver.save(_new_resource, _path)
	if err != 0:
		return
	previous_resource_picker.edited_resource = _new_resource
	
	manager_panel.update_resources()
	_set_state(StateType.NEW)
