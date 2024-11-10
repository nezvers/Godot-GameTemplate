class_name PhysicsHelper
extends Node

## Create a physics body with a single function call that shows all needed information in one place.
static func body_create_2d(space:RID, collision_layer:int, collision_mask:int, shape:Shape2D, transform:Transform2D, body_mode:PhysicsServer2D.BodyMode, instance_id:int)->RID:
	var body:RID = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_space(body, space)
	PhysicsServer2D.body_set_collision_layer(body, collision_layer)
	PhysicsServer2D.body_set_collision_mask(body, collision_mask)
	PhysicsServer2D.body_add_shape(body, shape.get_rid(), transform)
	PhysicsServer2D.body_set_mode(body, body_mode)
	PhysicsServer2D.body_set_omit_force_integration(body, true)
	PhysicsServer2D.body_attach_object_instance_id(body, instance_id)
	return body
