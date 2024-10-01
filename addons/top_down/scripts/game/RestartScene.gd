class_name RestartScene
extends Node

@export var player:Node

func _ready()->void:
	player.tree_exiting.connect(start_timer, CONNECT_ONE_SHOT)

func start_timer()->void:
	var tween:Tween = create_tween()
	tween.tween_callback(restart_scene).set_delay(1.0)

func restart_scene()->void: 
	get_tree().reload_current_scene()#.call_deferred()
