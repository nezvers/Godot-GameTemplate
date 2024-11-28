extends Node2D

@export var rigid_controler:Node

var velocity:Vector2

func _input(event:InputEvent)->void:
	if event is InputEventMouseButton:
		if event.is_released():
			#rigid_controler.move(get_local_mouse_position())
			velocity = get_local_mouse_position() * 0.1
	elif event is InputEventMouseMotion:
		queue_redraw()

func _draw() -> void:
	draw_line(Vector2.ZERO, get_local_mouse_position(), Color.WHITE)

func _process(delta: float) -> void:
	velocity = rigid_controler.move(velocity)
	velocity = velocity.move_toward(Vector2.ZERO, delta * 1.0)
