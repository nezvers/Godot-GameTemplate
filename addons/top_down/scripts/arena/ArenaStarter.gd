class_name ArenaStarter
extends Node

@export var fight_mode:BoolResource
@export var area:Area2D

func _ready()->void:
	# when started no need to keep Area2D
	fight_mode.changed_true.connect(owner.queue_free.call_deferred)
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body:Node2D)->void:
	# defered is thread safe, since this is called on physics thread
	fight_mode.set_value.call_deferred(true)
