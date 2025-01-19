class_name ActiveEnemy
extends Node


## Holds reference to instance to be spawned as key to reference it's representative counter, created by spawner.
## Globaly accessed through class_name.
static var instance_dictionary:Dictionary = {}

## Replaced or split enemy has to count as the same enemy, hence the tree like structure.
static var root:Dictionary = {parent = {}, count = int(0), callback = Callable()}

static var active_instances:Array[Node2D]

## Imagine slime enemy, each split has its own branch.
## Need to insert new child before removing self.
static func insert_child(node:Node, parent_branch:Dictionary, clear_callback:Callable = Callable())->void:
	instance_dictionary[node] = {parent = parent_branch, count = 0, callback = clear_callback}

## Handles counting active enemies with removing one from received branch
static func remove_count(branch:Dictionary)->void:
	branch.count -= 1
	
	if branch.count > 0:
		return
	
	var _callback:Callable = branch.callback
	if _callback.is_valid():
		_callback.call()
	
	if branch.parent.is_empty():
		return
	
	remove_count(branch.parent)
	# maybe not needed
	branch.clear()



## use nodes signal as trigger for pool_return()
@export var listen_node:Node

@export var signal_name:StringName

var my_dictionary:Dictionary

## trigger when instance counts as "killed", not when replaces self
func count_down()->void:
	remove_count(my_dictionary)

func _ready()->void:
	if listen_node != null:
		assert(listen_node.has_signal(signal_name))
		if !listen_node.is_connected(signal_name, count_down):
			listen_node.connect(signal_name, count_down)

## Grab dictionary representing instance branch. If owner is not in instance_dictionary use root
func _enter_tree() -> void:
	if instance_dictionary.has(owner):
		my_dictionary = instance_dictionary[owner]
	else:
		my_dictionary = root
	
	my_dictionary.count += 1
	
	active_instances.append(owner)

func _exit_tree() -> void:
	active_instances.erase(owner)
