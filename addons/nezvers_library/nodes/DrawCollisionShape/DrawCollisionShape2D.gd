@tool
extends CollisionShape2D
class_name DrawCollisionShape2D

@export var color:Color : set = set_color
@export var width:float = 1.0

func set_color(value:Color)->void:
	color = value
	queue_redraw()

func _draw()->void:
	if shape is CircleShape2D:
		var radius: = (shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, radius, color)
	elif shape is RectangleShape2D:
		var size:Vector2 = shape.size
		var rect: = Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y) 
		draw_rect(rect, color)
	elif shape is SeparationRayShape2D:
		#draw_line(Vector2.ZERO, Vector2.DOWN * shape.length, color, width)
		var rect: = Rect2(-width * 0.5, 0, width, shape.length)
		draw_rect(rect, color)
	elif shape is CapsuleShape2D:
		var radius: = (shape as CapsuleShape2D).radius
		draw_circle(Vector2(0.0, -shape.height * 0.5 + radius), radius, color)
		draw_circle(Vector2(0.0, shape.height * 0.5 - radius), radius, color)
		var size:Vector2 = Vector2(shape.radius * 2.0, max(shape.height - radius * 2, 0))
		var rect: = Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y) 
		draw_rect(rect, color)
	elif shape is SegmentShape2D:
		draw_line(shape.a, shape.b, color, 3.0)
	elif shape is ConvexPolygonShape2D:
		var colors:PackedColorArray = PackedColorArray()
		colors.resize(shape.points.size())
		draw_polygon(shape.points, colors)
	elif shape is ConcavePolygonShape2D:
		for i:int in shape.segments.size():
			var a:Vector2 = shape.segments[i * 2.0]
			var b:Vector2 = shape.segments[i * 2.0 + 1]
			draw_line(a, b, color, 3.0)
