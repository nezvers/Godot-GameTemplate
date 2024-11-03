## Updates UI
class_name InfoTracker
extends Node

@export var score_resource:ScoreResource
@export var health_resource:HealthResource
@export var fight_mode_resource:BoolResource
@export var wave_count_resource:IntResource
@export var enemy_count_resource:IntResource
@export var enemy_instance_resource:InstanceResource

@export var score_label:Label
@export var health_label:Label
@export var fight_mode_label:Label
@export var wave_count_label:Label
@export var enemy_count_label:Label
@export var active_count_label:Label


func _ready()->void:
	score_resource.points_updated.connect(update_score_label)
	update_score_label()
	
	health_resource.hp_changed.connect(update_health_label)
	update_health_label()
	
	fight_mode_resource.updated.connect(update_fight_mode_label)
	update_fight_mode_label()
	wave_count_resource.updated.connect(update_wave_count_label)
	update_wave_count_label()
	enemy_count_resource.updated.connect(update_enemy_count_label)
	update_enemy_count_label()
	enemy_instance_resource.updated.connect(update_active_count_label)
	update_active_count_label()

func update_score_label()->void:
	score_label.text = "Score: " + str(score_resource.point_count)

func update_health_label()->void:
	health_label.text = "HP: " + str(health_resource.hp)

func update_fight_mode_label()->void:
	fight_mode_label.text = "Fight Mode: " + ("ON" if fight_mode_resource.value else "OFF")

func update_wave_count_label()->void:
	wave_count_label.text = "Waves: " + str(wave_count_resource.value)

func update_enemy_count_label()->void:
	enemy_count_label.text = "Remaining Enemies: " + str(enemy_count_resource.value)

func update_active_count_label()->void:
	active_count_label.text = "Active: " + str(enemy_instance_resource.active_list.size())
