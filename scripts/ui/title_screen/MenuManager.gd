class_name MenuTraverseManager
extends Node

## String : NodePath
## Menu hierchy represented as node path and binds node with a NodePath
@export var menu_path:Dictionary
## Dictionary key reserved for nodes in a directory
# TODO: Explain better, I forgot myself
## Currently in each directory it holds node from menu_path
@export var node_key:String = "_node_"
@export var focused_node:Dictionary


## Use a dedicated resource for this task
var directory_resource:DictionaryDirectoryResource = DictionaryDirectoryResource.new()
## Keep in memory to know about previous directory
var current_directory:Dictionary

func _ready()->void:
	## Populate nodes in their directories
	for key:String in menu_path.keys():
		var path: = NodePath(key)
		var node:Node = get_node(menu_path[key])
		node.visible = false
		directory_resource.add_item(path, node, node_key)
	directory_resource.selected_directory_changed.connect(directory_changed)
	directory_changed()
	grab_focus.call_deferred(".")

## Hide previous node and show new
func directory_changed()->void:
	var node:Node = directory_get_node()
	if node != null:
		node.visible = false
	current_directory = directory_resource.directory_get_current()
	node = directory_get_node()
	if node != null:
		node.visible = true

## Retrieve node from a directory. If key doesn't exist, returns null.
func directory_get_node()->Node:
	if !current_directory.has(node_key):
		return null
	return current_directory[node_key]

## Sends method call to directory_resource
func open(value:String)->void:
	directory_resource.directory_open(value)
	grab_focus(value)

func grab_focus(value:String)->void:
	# Get node to focus
	if !focused_node.has(value):
		return
	var node:Control = get_node(focused_node[value])
	if node == null:
		return
	node.grab_focus()

## Sends method call to directory_resource
func back()->void:
	directory_resource.directory_back()
