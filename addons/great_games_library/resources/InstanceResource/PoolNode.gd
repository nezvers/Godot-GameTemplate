class_name PoolNode
extends Node

signal pool_requested()

## Mark nodes to trigger _ready() every time scene is added to the tree
@export var ready_nodes:Array[Node]

## AnimationPlayers that needs to be stopped and autoplay aniation played each time entering the tree
@export var animation_player_list:Array[AnimationPlayer]

## GPUParticles2D that has to be reset every time entering tree and remove previous particles from memory
@export var particle2d_list:Array[GPUParticles2D]

## use nodes signal as trigger for pool_return()
@export var listen_node:Node
@export var signal_name:StringName

var pool_was_requested:bool

func _ready()->void:
	pool_was_requested = false
	if listen_node != null:
		assert(listen_node.has_signal(signal_name))
		listen_node.connect(signal_name, pool_return, CONNECT_ONE_SHOT)

func pool_return()->void:
	if pool_was_requested:
		## For some stupid reason (Physics thread or something else), can call multiple times before removed from tree 
		return
	pool_was_requested = true
	request_ready()
	
	for _animation_player:AnimationPlayer in animation_player_list:
		_animation_player.stop()
	for _particle:GPUParticles2D in particle2d_list:
		if !_particle.tree_entered.is_connected(_particle.restart):
			_particle.tree_entered.connect(_particle.restart)
	for _node:Node in ready_nodes:
		_node.request_ready()
		
	pool_requested.emit()
