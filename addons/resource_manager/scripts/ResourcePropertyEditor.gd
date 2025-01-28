@tool class_name ResourcePropertyEditor
extends Node

@export var main_container:Control

var editor_resource_picker:EditorResourcePicker

var is_editable:bool

func _ready()->void:
	_set_editor_picker()

func setup(node:Control = null, resource:Resource = null, type:String = "")->void:
	if node != null:
		main_container.add_child(node)
		main_container.move_child(node, 0)
	
	_set_editor_picker()
	
	if !type.is_empty():
		editor_resource_picker.base_type = type
	
	if resource != null:
		editor_resource_picker.edited_resource = resource

func _set_editor_picker()->void:
	if editor_resource_picker != null:
		return
	editor_resource_picker = EditorResourcePicker.new()
	editor_resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_resource_picker.editable = true
	editor_resource_picker.resource_selected.connect(_on_resource_selected)
	editor_resource_picker.resource_changed.connect(_on_resource_changed)
	main_container.add_child(editor_resource_picker)

func _on_resource_selected(resource:Resource, inspect:bool)->void:
	is_editable = !is_editable
	pass

func _on_resource_changed(resource:Resource)->void:
	pass
