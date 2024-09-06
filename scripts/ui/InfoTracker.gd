class_name InfoTracker
extends Node

@export var score_resource:ScoreResource
@export var health_resource:HealthResource
@export var score_label:Label
@export var health_label:Label


func _ready()->void:
	score_resource.point_count = 0
	score_resource.points_updated.connect(update_score_label)
	update_score_label()
	
	health_resource.hp_changed.connect(update_health_label)
	update_health_label()

func update_score_label()->void:
	score_label.text = "Score: " + str(score_resource.point_count)

func update_health_label()->void:
	health_label.text = "HP: " + str(health_resource.hp)
