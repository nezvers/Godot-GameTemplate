extends RigidBody2D

onready var timeline_interface = $TimelineInterface
func _ready():
	timeline_interface.connect("get_frame", self, "get_frame")
	timeline_interface.connect("apply_frame", self, "apply_frame")
	timeline_interface.connect("playing_changed", self, "playing_changed")
		 
func get_frame():
	if not Engine.is_in_physics_frame():
		yield(get_tree(), "physics_frame")
	var physics_state = Physics2DServer.body_get_direct_state(get_rid())
	
	var transform = physics_state.transform
	var linear_velocity = physics_state.linear_velocity
	var angular_velocity = physics_state.angular_velocity
	
	var dir = Vector2.ZERO
	dir.x = Input.get_action_strength("Right") - Input.get_action_strength("Left")
	dir.y = Input.get_action_strength("Down") - Input.get_action_strength("Up")

	linear_velocity += dir*10;

	timeline_interface.done({
		"transform": transform,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity
	})

	global_transform = transform
	physics_state.transform = transform
	physics_state.linear_velocity = linear_velocity
	physics_state.angular_velocity = angular_velocity

	physics_state.integrate_forces()


func apply_frame(frame, prev_frame, delta):
	if not Engine.is_in_physics_frame():
		yield(get_tree(), "physics_frame")
	var physics_state = Physics2DServer.body_get_direct_state(get_rid())
	
	var transform = prev_frame.transform.interpolate_with(frame.transform, delta)
	var linear_velocity = prev_frame.linear_velocity.linear_interpolate(frame.linear_velocity, delta)
	var angular_velocity = lerp(prev_frame.angular_velocity, frame.angular_velocity, delta);
	
	global_transform = transform
	physics_state.transform = transform
	physics_state.linear_velocity = linear_velocity
	physics_state.angular_velocity = angular_velocity

	physics_state.integrate_forces()


func playing_changed(playing):
	var PLAYING = timeline_interface.PLAYING
	if playing == PLAYING.PAUSED:
		call_deferred("set_mode", RigidBody2D.MODE_STATIC)
	elif playing == PLAYING.PLAYING:
		call_deferred("set_mode", RigidBody2D.MODE_RIGID)




