extends Node

signal Resized

var Fullscreen = OS.window_fullscreen setget set_fullscreen
var Borderless = OS.window_borderless setget set_borderless
var VolumeMaster:float = 0.0 setget set_volume_master
var VolumeMusic:float = 0.0 setget set_volume_music
var VolumeSFX:float = 0.0 setget set_volume_sfx
var VolumeRange:float = 24 + 80
var View:Viewport
var ViewRect2:Rect2
var GameResolution:Vector2
var WindowResolution:Vector2
var ScreenResolution:Vector2
var ScreenAspectRatio:float
var Scale:int = 4 setget set_scale
var MaxScale:int

func _ready()->void:
	get_resolution()
	get_volumes()

func set_fullscreen(value:bool)->void:
	Fullscreen = value
	OS.window_fullscreen = value
	WindowResolution = OS.window_size

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

func get_volumes()->void:
	var Master:float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	var Music:float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var SFX:float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	
	VolumeMaster = ((Master +80))/ VolumeRange
	VolumeMusic = ((Music +80))/ VolumeRange
	VolumeSFX = ((SFX +80))/ VolumeRange

func set_scale(value:int)->void:
	Scale = clamp(value, 1, MaxScale)
	if Scale == MaxScale:
		OS.window_fullscreen = true
		Fullscreen = true
	else:
		OS.window_fullscreen = false
		Fullscreen = false
		OS.window_size = GameResolution * Scale
		OS.center_window()
	get_resolution()
	emit_signal("Resized")

func set_volume_master(volume:float)->void:
	VolumeMaster = clamp(volume, 0.0, 1.0)
	var Master = lerp(-80, 24, VolumeMaster)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), Master)

func set_volume_music(volume:float)->void:
	VolumeMusic = clamp(volume, 0.0, 1.0)
	var Music = lerp(-80, 24, VolumeMusic)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), Music)

func set_volume_sfx(volume:float)->void:
	VolumeSFX = clamp(volume, 0.0, 1.0)
	var SFX = lerp(-80, 24, VolumeSFX)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), SFX)