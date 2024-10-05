## Class that draws CollisionShape2D shape in given color
@tool
class_name DrawCollisionShape2D
extends CollisionShape2D

@export var color:Color : set = set_color

func set_color(value:Color)->void:
	color = value
	queue_redraw()

func _draw()->void:
	Drawer.draw_shape2d(self, shape, color)
