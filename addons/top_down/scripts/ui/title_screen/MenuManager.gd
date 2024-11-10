class_name MenuTraverseManager
extends Node

## String : NodePath
## Menu hierchy represented as node path and binds node with a NodePath.
## Key is directory path and value is a reference to a node that will be set visible.
@export var menu_path:Dictionary

# TODO: Explain better, I forgot myself
## Dictionary key reserved for nodes in a directory
## Currently in each directory it holds node from menu_path
@export var node_key:String = "_node_"

## Reference node that needs to be focused when specific directory is activated
@export var focused_node:Dictionary

@export var back_sound:SoundResource

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
	directory_grab_focus.call_deferred(".")

## Hide previous node and show new
func directory_changed()->void:
	var node:Node = directory_get_node(node_key)
	if node != null:
		node.visible = false
	current_directory = directory_resource.directory_get_current()
	node = directory_get_node(node_key)
	if node != null:
		node.visible = true

## Retrieve node from a directory. If key doesn't exist, returns null.
func directory_get_node(key:String)->Node:
	if !current_directory.has(key):
		return null
	return current_directory[key]

## Sends method call to directory_resource
func open(value:String)->void:
	directory_resource.directory_open(value)
	directory_grab_focus(value)

func directory_grab_focus(value:String)->void:
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
	if back_sound != null:
		back_sound.play_managed()
