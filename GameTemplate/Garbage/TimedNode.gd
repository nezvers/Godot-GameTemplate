extends RigidBody2D

func get_state():
    var physics_state = Physics2DServer.body_get_direct_state(get_rid())

    return {
        "transform": physics_state.transform,
        "linear_velocity": physics_state.linear_velocity,
        "angular_velocity": physics_state.angular_velocity
    }

func apply_state(state, prev_state, delta):
    var physics_state = Physics2DServer.body_get_direct_state(get_rid())

    global_transform = prev_state.transform.interpolate_with(state.transform, delta)
    physics_state.transform = global_transform
    physics_state.linear_velocity = prev_state.linear_velocity.linear_interpolate(state.linear_velocity, delta)
    physics_state.angular_velocity = lerp(prev_state.angular_velocity, state.angular_velocity, delta)

    physics_state.integrate_forces()