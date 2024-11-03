class_name PoolNode
extends Node

signal pool_requested

@export var ready_nodes:Array[Node]
@export var animation_player_list:Array[AnimationPlayer]
@export var particle2d_list:Array[GPUParticles2D]

func pool_return()->void:
	for _animation_player:AnimationPlayer in animation_player_list:
		_animation_player.stop()
	for _particle:GPUParticles2D in particle2d_list:
		_particle.tree_entered.connect(_particle.restart, CONNECT_ONE_SHOT)
	for _node:Node in ready_nodes:
		_node.request_ready()
	
	pool_requested.emit()
