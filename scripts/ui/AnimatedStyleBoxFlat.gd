## Used to list style properties that needs to be tweened between states
class_name AnimatedStyleBoxFlat
extends StyleBoxFlat

@export var tween_time:float = 0.0
@export var tween_list:Array[StringName] =[
	"content_margin_bottom",
	"content_margin_left",
	"content_margin_right",
	"content_margin_top",
	"anti_aliasing",
	"anti_aliasing_size",
	"bg_color",
	"border_blend",
	"border_color",
	"border_width_bottom",
	"border_width_left",
	"border_width_right",
	"border_width_top",
	"corner_detail",
	"corner_radius_bottom_left",
	"corner_radius_bottom_right",
	"corner_radius_top_left",
	"corner_radius_top_right",
	"draw_center",
	"expand_margin_bottom",
	"expand_margin_left",
	"expand_margin_right",
	"expand_margin_top",
	"shadow_color",
	"shadow_offset",
	"shadow_size",
	"skew",
]
@export var label_settings:LabelSettings
@export var label_tween_list:Array[StringName] = [
	"font_color",
	"font_size",
	"line_spacing",
	"outline_color",
	"outline_size",
	"shadow_color",
	"shadow_offset",
	"shadow_size"
]
