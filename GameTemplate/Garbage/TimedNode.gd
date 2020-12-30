extends RigidBody2D

func get_state():
    var physics_state = Physics2DServer.body_get_direct_state(get_rid())

    return {
        "transform": physics_state.transform,
        "linear_velocity": physics_state.linear_velocity,
        "angular_velocity": physics_state.angular_velocity
    }

func apply_state(state):
    var physics_state = Physics2DServer.body_get_direct_state(get_rid())

    global_transform = state.transform
    physics_state.transform = state.transform
    physics_state.linear_velocity = state.linear_velocity
    physics_state.angular_velocity = state.angular_velocity

    physics_state.integrate_forces()

