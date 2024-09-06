extends Node

@export var hitbox:Hitbox
@export var score_resource:ScoreResource


func _ready():
	hitbox.health_resource.dead.connect(score_resource.add_point)

