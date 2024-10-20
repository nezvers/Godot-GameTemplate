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
