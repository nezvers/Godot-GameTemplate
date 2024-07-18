extends Node

signal Resized

#SCREEN
var Fullscreen = false
var Borderless = false
var View:Window
var ViewRect2:Rect2
var WindowResolution:Vector2
var GameResolution:Vector2
var ScreenResolution:Vector2
var ScreenAspectRatio:float
var Scale:int = 3: set = set_scale
var MaxScale:int

#RESOLUTION
func set_fullscreen(value:bool)->void:
	Fullscreen = value
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (value) else Window.MODE_WINDOWED
	if value:
		set_scale(MaxScale)
	else:
		set_scale(Scale - 1)

func set_borderless(value:bool)->void:
	Borderless = value
	get_window().borderless = value
	set_scale(Scale)

func get_resolution()->void:
	View = get_viewport()
	ViewRect2 = View.get_visible_rect()
	GameResolution = ViewRect2.size
	
	WindowResolution = DisplayServer.screen_get_size()
	ScreenResolution = DisplayServer.screen_get_size()
	ScreenAspectRatio = ScreenResolution.x/ScreenResolution.y
	MaxScale = ceil(ScreenResolution.y / GameResolution.y)

func set_scale(value:int)->void:
	Scale = clamp(value, 1, MaxScale)
	if Scale >= MaxScale:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (true) else Window.MODE_WINDOWED
		Fullscreen = true
	else:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (false) else Window.MODE_WINDOWED
		Fullscreen = false
		get_window().size = GameResolution * Scale
		get_window().move_to_center()
	get_resolution()
	emit_signal("Resized")


#SAVING RESOLUTION
func get_resolution_data()->Dictionary:
	var resolution_data:Dictionary = {}
	resolution_data["Borderless"] = Borderless
	resolution_data["Scale"] = Scale
	return resolution_data

#LOADING RESOLUTION

func set_resolution_data(resolution:Dictionary)->void:
	SettingsResolution.set_borderless(resolution.Borderless)
	SettingsResolution.set_scale(resolution.Scale)
