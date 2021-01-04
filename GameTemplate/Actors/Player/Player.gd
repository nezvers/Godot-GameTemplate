extends KinematicBody2D

enum STATE { PLAYING, 
REPLAYING, 
PAUSED }
var velocity = Vector2()
var timelien_state;
# Declare member variables here. Examples:



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _timeline_state_update(state):


func _physics_process(delta):
	if timeline.state === STATE.PLAYING: 
	move_and_slide(velocity, Vector2.UP, false, 4, deg2rad(45), true)
