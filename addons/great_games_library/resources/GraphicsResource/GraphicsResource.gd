class_name GraphicsResource
extends SaveableResource

signal window_mode_changed
signal borderless_changed

@export var window_mode:DisplayServer.WindowMode
@export var window_flags:Array[bool] = [false, true, false, false, false, false, false]

@export var borderless:bool
@export var window_position:Vector2i
@export var window_size:Vector2i = Vector2i(1280, 720)
@export var screen:int
@export var window_rect:Rect2i
@export var screen_count:int
@export var safe_area:Rect2i

var previous_mode:DisplayServer.WindowMode
var is_inside:bool

## Override for creating data Resource that will be saved with the ResourceSaver
func prepare_save()->Resource:
	read_properties()
	if window_mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		window_mode = previous_mode
	
	print("GraphicResource [Saving]")
	return self.duplicate()

## Override to ad logic for reading loaded data and applying to current instance of the Resource
func prepare_load(data:Resource)->void:
	for i:int in window_flags.size():
		set_window_flag(i, data.window_flags[i])
	set_window_size(data.window_size)
	set_window_position(data.window_position)
	set_window_mode(data.window_mode)
	previous_mode = data.window_mode
	window_rect = data.window_rect
	screen = data.screen
	is_inside_screen()
	if window_mode != DisplayServer.WINDOW_MODE_FULLSCREEN && !is_inside:
		set_window_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	
	print("GraphicResource [Loaded]")

## Override function for resetting to default values
func reset_resource()->void:
	set_window_mode(window_mode)
	previous_mode = window_mode
	for i:int in window_flags.size():
		set_window_flag(i, window_flags[i])

func enable_resize_tracking(viewport:Viewport)->void:
	if !viewport.size_changed.is_connected(size_changed):
		viewport.size_changed.connect(size_changed)

func size_changed()->void:
	read_properties()

func read_properties()->void:
	# find flag
	for i:int in window_flags.size():
		window_flags[i] = DisplayServer.window_get_flag(i, 0)
	window_size = DisplayServer.window_get_size(0)
	window_position = DisplayServer.window_get_position(0)
	window_rect = Rect2i(window_position,window_size)
	screen = DisplayServer.window_get_current_screen(0)
	is_inside_screen()
	screen_count = DisplayServer.get_screen_count()
	
	print("GraphicsResource [properties]: mode = ", window_mode, ", flags = ", window_flags, ", pos = ", window_position, ", size = ", window_size)


func set_window_position(value:Vector2i)->void:
	DisplayServer.window_set_position(value, 0)
	window_position = value
	print("set_window_position: ", value)

func set_window_size(value:Vector2i)->void:
	window_size = value
	DisplayServer.window_set_size(value, 0)
	print("set_window_size: ", value)

func set_window_mode(value:int)->void:
	previous_mode = window_mode
	var mode: = value as DisplayServer.WindowMode
	var need_borderless:bool = mode == DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN
	window_mode = mode
	set_borderless(need_borderless)
	DisplayServer.window_set_mode(mode, 0)
	window_mode_changed.emit()
	print("set_window_mode: ", mode)

func set_window_flag(flag_index:int, value:bool)->void:
	if flag_index == DisplayServer.WINDOW_FLAG_POPUP:
		# Ignore - Error message about main window can't be popup
		return
	window_flags[flag_index] = value
	DisplayServer.window_set_flag(flag_index, value, 0)

func is_borderless()->bool:
	return DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, 0)

func is_fullscreen()->bool:
	return window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN

func toggle_fullscreen()->void:
	if window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		set_window_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_borderless(value:bool)->void:
	window_flags[DisplayServer.WINDOW_FLAG_BORDERLESS] = value
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, value, 0)
	print("set borderless: ", value)
	borderless_changed.emit()

func is_inside_screen()->bool:
	safe_area = DisplayServer.get_display_safe_area()
	is_inside = safe_area.intersection(window_rect) == window_rect
	print("inside: ", is_inside)
	return is_inside
