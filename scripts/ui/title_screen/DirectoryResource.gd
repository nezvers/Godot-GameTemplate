class_name DictionaryDirectoryResource
extends SaveableResource

signal selected_directory_changed

## shows selected directory
@export var selected_directory:NodePath = NodePath(".")

## Holds tree like structure Dictionaries to represent directories
@export var directory_tree:Dictionary = { "." = {} }
#   {
#   	"." = {
#   		"_item_type_" = MyItem,
#   		
#   		"options" = {
#   			"graphics" = {},
#   			"audio" = {},
#   			"controls" = {}
#   		}
#   	}
#   }

## Override function for resetting to default values
## Init to root directory
func reset_resource()->void:
	directory_tree = { "." = {} }
	selected_directory = NodePath(".")

## Notify with a selected_directory_changed signal.
func set_selected_directory(value:NodePath)->void:
	selected_directory = value
	selected_directory_changed.emit()

## Adds a node in its dedicated directory
func add_item(path:NodePath, node:Node, node_name:String)->void:
	var current_directory:Dictionary = directory_get(path, true)
	current_directory[node_name] = node

## Retrieved dictionary that holds data about a directory
func directory_get(path:NodePath, create:bool = false)->Dictionary:
	# TODO: Maybe for security purposes, if node_key represents non-directory-list, need to check access rights
	var current_directory:Dictionary = directory_tree
	for i in path.get_name_count():
		var path_name: = path.get_name(i)
		if !current_directory.has(path_name):
			if create:
				current_directory[path_name] = {}
			else:
				break
		if !(current_directory[path_name] is Dictionary):
			break
		current_directory = current_directory[path_name]
	return current_directory

## shorthand for directory_get(selected_directory)
func directory_get_current()->Dictionary:
	return directory_get(selected_directory)

## Travers to parent directory. Root directory can't go back.
func directory_back()->void:
	if selected_directory.get_name_count() <= 1:
		## Root directory is selected. Can't go back. Don't signal.
		return
	var path:String = selected_directory.get_name(0)
	var dir_count:int = selected_directory.get_name_count()
	for i in dir_count -2:
		path += "/" + selected_directory.get_name(i + 1)
	set_selected_directory( NodePath(path) )

## If current directory contains a child directory with specified name, the selected_directory will be updated
func directory_open(value:String)->void:
	var current_directory:Dictionary = directory_get(selected_directory)
	if !current_directory.has(value):
		return
	set_selected_directory( NodePath(str(selected_directory) + "/"+ value) )
