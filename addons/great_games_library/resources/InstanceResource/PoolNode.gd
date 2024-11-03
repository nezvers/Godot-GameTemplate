class_name PoolNode
extends Node

signal pool_requested

## Mark nodes to trigger _ready() every time scene is added to the tree
@export var ready_nodes:Array[Node]
## AnimationPlayers that needs to be stopped and autoplay aniation played each time entering the tree
@export var animation_player_list:Array[AnimationPlayer]
## GPUParticles2D that has to be reset every time entering tree and remove previous particles from memory
@export var particle2d_list:Array[GPUParticles2D]

func pool_return()->void:
	for _animation_player:AnimationPlayer in animation_player_list:
		_animation_player.stop()
	for _particle:GPUParticles2D in particle2d_list:
		_particle.tree_entered.connect(_particle.restart, CONNECT_ONE_SHOT)
	for _node:Node in ready_nodes:
		_node.request_ready()
	
	pool_requested.emit()
