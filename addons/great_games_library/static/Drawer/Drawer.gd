extends Node2D
class_name Drawer

static func draw_ring(node:CanvasItem, radius:float, resolution:int, rotated:float = 0.0, color:Color = Color.WHITE, width:float = -1)->void:
	var increments: float = TAU / resolution
	var rad: = rotated
	var to: = Vector2.ZERO
	var from: = Vector2(cos(rad)*radius, sin(rad)*radius)
	for i in resolution:
		rad = rotated + increments * (i+1)
		to = Vector2(cos(rad)*radius, sin(rad)*radius)
		node.draw_line(from, to, color, width)
		from = to

static func draw_shape2d(node:CanvasItem, shape:Shape2D, color:Color)->void:
	if shape is CircleShape2D:
		var _radius: = (shape as CircleShape2D).radius
		node.draw_circle(Vector2.ZERO, _radius, color)
	elif shape is RectangleShape2D:
		var _size:Vector2 = shape.size
		var _rect: = Rect2(-_size.x * 0.5, -_size.y * 0.5, _size.x, _size.y) 
		node.draw_rect(_rect, color)
	elif shape is SeparationRayShape2D:
		var _width:float = 3.0
		var _rect: = Rect2(-_width * 0.5, 0, _width, shape.length)
		node.draw_rect(_rect, color)
	elif shape is CapsuleShape2D:
		var _radius: = (shape as CapsuleShape2D).radius
		node.draw_circle(Vector2(0.0, -shape.height * 0.5 + _radius), _radius, color)
		node.draw_circle(Vector2(0.0, shape.height * 0.5 - _radius), _radius, color)
		var _size:Vector2 = Vector2(shape.radius * 2.0, max(shape.height - _radius * 2, 0))
		var _rect: = Rect2(-_size.x * 0.5, -_size.y * 0.5, _size.x, _size.y) 
		node.draw_rect(_rect, color)
	elif shape is SegmentShape2D:
		var _width:float = 3.0
		node.draw_line(shape.a, shape.b, color, _width)
	elif shape is ConvexPolygonShape2D:
		var _colors:PackedColorArray = PackedColorArray()
		_colors.resize(shape.points.size())
		_colors.fill(color)
		node.draw_polygon(shape.points, _colors)
	elif shape is ConcavePolygonShape2D:
		for i:int in shape.segments.size():
			var _a:Vector2 = shape.segments[i * 2.0]
			var _b:Vector2 = shape.segments[i * 2.0 + 1]
			node.draw_line(_a, _b, color, 3.0)
