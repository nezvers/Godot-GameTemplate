class_name ActiveEnemy
extends Node


## Holds reference to instance to be spawned as key to reference it's representative resource, created by spawner.
## Globaly accessed through class_name.
static var instance_dictionary:Dictionary = {}

## Replaced or split enemy has to count as the same enemy, hence the tree like structure.
static var root:ActiveEnemyResource = ActiveEnemyResource.new()

static var active_instances:Array[Node2D]

## Imagine slime enemy, each split has its own branch.
## Need to insert new child before removing self.
static func insert_child(node:Node, parent_branch:ActiveEnemyResource, clear_callback:Callable = Callable())->void:
	var _active_enemy_resource:ActiveEnemyResource = ActiveEnemyResource.new()
	_active_enemy_resource.parent = parent_branch
	_active_enemy_resource.clear_callback = clear_callback
	instance_dictionary[node] = _active_enemy_resource
	
	if parent_branch == null:
		return
	parent_branch.children.append(_active_enemy_resource)

## Handles counting active enemies with removing one from received branch
static func remove_branch(branch:ActiveEnemyResource, caller:ActiveEnemy)->void:
	if !branch.nodes.is_empty():
		return
	
	if !branch.children.is_empty():
		return
	
	if branch.clear_callback.is_valid():
		branch.clear_callback.call(caller)
	
	if branch.parent == null:
		return
	
	assert(branch.parent.children.has(branch))
	branch.parent.children.erase(branch)
	
	if !branch.parent.children.is_empty():
		return
	
	remove_branch(branch.parent, caller)

static func destroy_children_enemies(branch:ActiveEnemyResource)->void:
	for _enemy:ActiveEnemy in branch.nodes:
		_enemy.self_destruct()
	for _child_branch in branch.children:
		destroy_children_enemies(_child_branch)

## use nodes signal for removing self from active enemy data tree
@export var listen_node:Node

@export var signal_name:StringName

@export var resource_node:ResourceNode

@export var destroy_children:bool

var enemy_resource:ActiveEnemyResource

## trigger when instance counts as "killed", but not when replaces self
func remove_self()->void:
	if destroy_children:
		# since elements gets removed from array, start from end
		var _children_count:int = enemy_resource.children.size()
		for i:int in _children_count:
			var _child_branch:ActiveEnemyResource = enemy_resource.children[_children_count - 1 - i]
			destroy_children_enemies(_child_branch)
	
	enemy_resource.nodes.erase(self)
	remove_branch(enemy_resource, self)


func _ready()->void:
	if listen_node != null:
		assert(listen_node.has_signal(signal_name))
		if !listen_node.is_connected(signal_name, remove_self):
			listen_node.connect(signal_name, remove_self)

## Grab dictionary representing instance branch. If owner is not in instance_dictionary use root
func _enter_tree() -> void:
	if instance_dictionary.has(owner):
		enemy_resource = instance_dictionary[owner]
		instance_dictionary.erase(owner)
	else:
		enemy_resource = root
	
	enemy_resource.nodes.append(self)
	
	active_instances.append(owner)
	
	# Call with reference because when they are called owner can be null
	tree_exiting.connect(_on_exiting_tree.bind(owner), CONNECT_ONE_SHOT)

## owner could be null when _exit_tree() is called
func _on_exiting_tree(owner_reference:Node2D) -> void:
	assert(owner_reference != null)
	active_instances.erase(owner_reference)
	assert(!active_instances.has(owner_reference))
	for inst:Node2D in active_instances:
		assert(inst != null)

func self_destruct()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	_health_resource.insta_kill()
