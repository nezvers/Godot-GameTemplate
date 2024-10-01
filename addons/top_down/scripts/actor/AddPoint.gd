extends Node

@export var damage_receiver:DamageReceiver
@export var score_resource:ScoreResource


func _ready():
	damage_receiver.health_resource.dead.connect(score_resource.add_point)
