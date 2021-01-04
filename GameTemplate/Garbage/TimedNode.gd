extends RigidBody2D

onready var timeline_interface = $TimelineInterface

func _on_TimelineInterface_get_frame():
	
	var physics_state = Physics2DServer.body_get_direct_state(get_rid())
	
	var transform = physics_state.transform
	var linear_velocity = physics_state.linear_velocity
	var angular_velocity = physics_state.angular_velocity
	
	timeline_interface.done({
		"transform": transform,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity
	})


func _on_TimelineInterface_apply_frame(frame, prev_frame, delta):
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


func _on_TimelineInterface_playing_changed(playing):
	var PLAYING = timeline_interface.PLAYING
	if playing == PLAYING.PAUSED:
		call_deferred("set_mode", RigidBody2D.MODE_STATIC)
	elif playing == PLAYING.PLAYING:
		call_deferred("set_mode", RigidBody2D.MODE_RIGID)

