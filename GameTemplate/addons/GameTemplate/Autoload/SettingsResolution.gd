extends Node

signal Resized

#SCREEN
var Fullscreen = false setget set_fullscreen
var Borderless = false setget set_borderless
var View:Viewport
var ViewRect2:Rect2
var GameResolution:Vector2
var WindowResolution:Vector2
var ScreenResolution:Vector2
var ScreenAspectRatio:float
var Scale:int = 3 setget set_scale				#Default scale multiple
var MaxScale:int

#RESOLUTION
func set_fullscreen(value:bool)->void:
	Fullscreen = value
	OS.window_fullscreen = value
	if value:
		set_scale(MaxScale)
	else:
		OS.center_window()
		set_scale(OS.window_size.x/GameResolution.x)

func set_borderless(value:bool)->void:
	Borderless = value
	OS.window_borderless  = value

func get_resolution()->void:
	View = get_viewport()
	ViewRect2 = View.get_visible_rect()
	GameResolution = ViewRect2.size
	
	WindowResolution = OS.window_size
	ScreenResolution = OS.get_screen_size(OS.current_screen)
	ScreenAspectRatio = ScreenResolution.x/ScreenResolution.y
	MaxScale = ceil(ScreenResolution.y/ GameResolution.y)

func set_scale(value:int)->void:
	Scale = clamp(value, 1, MaxScale)
	if Scale >= MaxScale:
		OS.window_fullscreen = true
		Fullscreen = true
	else:
		OS.window_fullscreen = false
		Fullscreen = false
		OS.window_size = GameResolution * Scale
		OS.center_window()
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
