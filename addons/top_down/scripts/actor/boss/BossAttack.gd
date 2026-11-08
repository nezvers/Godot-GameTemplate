## One boss attack. BossAttackLoop picks it when available, stops the boss, plays the animation
## stretched over windup (the telegraph), calls perform(), then waits recovery (punish window).
class_name BossAttack
extends Node

## CharacterAnimator animation played during windup
@export var animation:StringName

## Telegraph time before perform(), animation is stretched to fit
@export var windup:float = 0.6

## Optional animation played when perform() starts (charging run)
@export var perform_animation:StringName

@export var perform_animation_speed:float = 1.0

## Boss stands still after the attack
@export var recovery:float = 0.6

@export var cooldown:float = 3.0

@export var min_distance:float = 0.0

@export var max_distance:float = 9999.0

## Available only while health ratio is inside the range, used for fight phases
@export_range(0.0, 1.0) var min_health:float = 0.0
@export_range(0.0, 1.0) var max_health:float = 1.0

## Chance compared to other available attacks
@export var weight:float = 1.0

## Optional ground warning shown during windup
@export var telegraph:BossTelegraph

var ready_time:float

var target:Node2D

## perform() can extend recovery (charge hit a wall)
var extra_recovery:float

## false when interrupted, long attacks check it between frames
var running:bool

func is_available(time:float, distance:float, health_ratio:float)->bool:
	if time < ready_time:
		return false
	if distance < min_distance || distance > max_distance:
		return false
	return health_ratio >= min_health && health_ratio <= max_health

## Whether it can be used on this target right now (a jump whose landing spot is
## a hole waits); checked with is_available when the loop picks an attack.
func can_target(_target:Node2D)->bool:
	return true

## Windup start, target is known
func prepare(new_target:Node2D)->void:
	target = new_target
	extra_recovery = 0.0
	running = true

## After windup, can be a coroutine
func perform()->void:
	pass

## Finished or interrupted (death, pooled), restore everything changed by perform()
func stop()->void:
	running = false

func has_target()->bool:
	return is_instance_valid(target) && target.is_inside_tree()
