@tool
extends Label


@export var auto_size_height: bool = true:
	set(value):
		auto_size_height = value
		queue_redraw()


func _init() -> void:
	draw.connect(__before_draw)


func __before_draw() -> void:
	# This is needed if wrapping is turned on in an autosized label,
	# otherwise the conatiner will give 0 height
	# (As the label itself cannot decide what size to ask from the container
	# as due to wrapping, no size is fixed. But fortunatelly the label
	# makes internal calculation according to intended width before the draw)
	if auto_size_height:
		var stylebox := get_theme_stylebox(&"normal")
		var line_spacing = get_theme_constant(&"line_spacing")
		var height := max(0, stylebox.content_margin_top)
		for i in get_line_count():
			if max_lines_visible >= 0 and i >= max_lines_visible:
				break
			if i > 0:
				height += line_spacing
			height += get_line_height(i)
		height += max(0, stylebox.content_margin_bottom)
		custom_minimum_size.y = height
