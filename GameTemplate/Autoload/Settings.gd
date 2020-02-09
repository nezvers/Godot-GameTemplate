extends Node

signal Resized
signal ReTranslate

#OS
var HTML5:bool = false
#SCREEN
var Fullscreen = OS.window_fullscreen setget set_fullscreen
var Borderless = OS.window_borderless setget set_borderless
var View:Viewport
var ViewRect2:Rect2
var GameResolution:Vector2
var WindowResolution:Vector2
var ScreenResolution:Vector2
var ScreenAspectRatio:float
var Scale:int = 3 setget set_scale
var MaxScale:int
#AUDIO
var VolumeMaster:float = 0.0 setget set_volume_master
var VolumeMusic:float = 0.0 setget set_volume_music
var VolumeSFX:float = 0.0 setget set_volume_sfx
var VolumeRange:float = 24 + 80
#CONTROLS
var Actions:Array = ["Right", "Left", "Up", "Down", "Jump"]
var ActionControls:Dictionary = {}
#Localization
onready var Language:String = TranslationServer.get_locale() setget set_language
var Language_dictionary:Dictionary = {EN = "en", DE = "de", ES = "es", FR = "fr", BR = "pt_BR", LV = "lv", IT = "it"} #Font doesn't have Cyrillic letters for russian
var Language_list:Array = Language_dictionary.keys()
#var Save / Load
var CONFIG_FILE:String = "user://settings.save"
var Settings_loaded:bool = false

func _ready()->void:
	if OS.get_name() == "HTML5":
		HTML5 = true
	get_resolution()
	load_settings()
	get_volumes()
	get_controls()
	#save_settings() #Call this method to trigger Settings saving


#RESOLUTION
func set_fullscreen(value:bool)->void:
	Fullscreen = value
	OS.window_fullscreen = value
	WindowResolution = OS.window_size
	if value:
		Scale = MaxScale

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
#AUDIO
func get_volumes()->void:
	var Master:float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	var Music:float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var SFX:float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	
	VolumeMaster = ((Master +80))/ VolumeRange
	VolumeMusic = ((Music +80))/ VolumeRange
	VolumeSFX = ((SFX +80))/ VolumeRange

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

#CONTROLS
func get_controls()->void:
	if !Settings_loaded:
		default_controls()
	set_actions_info()

func default_controls()->void:	#Reset to project settings controls
	InputMap.load_from_globals()
	set_actions_info()

func set_actions_info()->void:
	ActionControls.clear()
	for Action in Actions:
		var ActionList:Array = InputMap.get_action_list(Action) #associated controlls to the action
		ActionControls[Action] = ActionList

func print_events_list(ActionList:Array)->void:
	for event in ActionList:
		print(event.as_text())

func set_language(value:String)->void:
	Language = value
	TranslationServer.set_locale(value)
	emit_signal("ReTranslate")

#Save/ Load
#Call this method to trigger Settings saving
func save_settings()->void:
	var SaveSettings:File = File.new()
	SaveSettings.open(CONFIG_FILE, File.WRITE)
	var save_data:Dictionary = get_save_data()
	SaveSettings.store_line(to_json(save_data))
	SaveSettings.close()

func load_settings()->void:
	if Settings.HTML5: #need to confirm but for now don't use for HTML5
		return
	#Json to Dictionary
	var SaveSettings:File = File.new()
	if !SaveSettings.file_exists(CONFIG_FILE):
		return  #We don't have a save to load
	Settings_loaded = true
	SaveSettings.open(CONFIG_FILE, File.READ)
	var save_data
	save_data = parse_json(SaveSettings.get_line())
	SaveSettings.close()
	#Dictionary to Settings
	set_save_data(save_data)

func get_save_data()->Dictionary:
	var savedata: = {
		inputs = get_input_data(),
		resolution = get_resolution_data(),
		audio = get_audio_data(),
		language = {locale = TranslationServer.get_locale()}
		}
	return savedata

func get_input_data()->Dictionary:
	var inputs:Dictionary = {}
	for action_name in Actions:
		var button_list_data:Dictionary = {}
		var button_list:Array = ActionControls[action_name]
		var index:int = 0
		for button in button_list:
			button_list_data[index] = get_button_data(button)
			index += 1
		inputs[action_name] = button_list_data
	return inputs

func get_button_data(event)->Dictionary:
	var button_data:Dictionary = {}
	if event is InputEventKey:
		button_data["EventType"] = "InputEventKey"
		button_data["scancode"] = event.scancode
	if event is InputEventJoypadButton:
		button_data["EventType"] = "InputEventJoypadButton"
		button_data["device"] = event.device
		button_data["button_index"] = event.button_index
	if event is InputEventJoypadMotion:
		button_data["EventType"] = "InputEventJoypadMotion"
		button_data["device"] = event.device
		button_data["axis"] = event.axis
		button_data["axis_value"] = event.axis_value
	return button_data

func set_save_data(save_data:Dictionary)->void:
	if save_data.has("inputs"):
		set_ActionControlls_default()
		set_input_data(save_data.inputs)
	if save_data.has("resolution"):
		set_resolution_data(save_data.resolution)
	if save_data.has("audio"):
		set_audio_data(save_data.audio)
	if save_data.has("language"):
		set_language(save_data.language.locale)

func set_ActionControlls_default()->void:
	for action_name in Actions:
		ActionControls[action_name] = []

func set_input_data(inputs:Dictionary)->void:
	var action_names:Array = inputs.keys()
	for action_name in action_names:
		var button_list:Array
		var button_names = inputs[action_name].keys()
		for button_name in button_names:
			var button = inputs[action_name][button_name]
			var event:InputEvent = set_button_data(button)
			Settings.ActionControls[action_name].push_back(event)
	set_InputMap()
	
func set_button_data(button:Dictionary)->InputEvent:
	var NewEvent:InputEvent
	if button.EventType == "InputEventKey":
		NewEvent = InputEventKey.new()
		NewEvent.scancode = button.scancode
	if button.EventType == "InputEventJoypadButton":
		NewEvent = InputEventJoypadButton.new()
		NewEvent.device = button.device
		NewEvent.button_index = button.button_index
	if button.EventType == "InputEventJoypadMotion":
		NewEvent = InputEventJoypadMotion.new()
		NewEvent.device = button.device
		NewEvent.axis = button.axis
		NewEvent.axis_value = button.axis_value
	return NewEvent

func set_InputMap()->void:
	for action_name in Actions:
		InputMap.action_erase_events(action_name)
		for event in ActionControls[action_name]:
			InputMap.action_add_event(action_name, event)

func get_resolution_data()->Dictionary:
	var resolution_data:Dictionary = {}
	resolution_data["Fullscreen"] = Fullscreen
	resolution_data["Borderless"] = Borderless
	resolution_data["Scale"] = Scale
	return resolution_data

func set_resolution_data(resolution:Dictionary)->void:
	set_fullscreen(resolution.Fullscreen)
	set_borderless(resolution.Borderless)
	set_scale(resolution.Scale)

func get_audio_data()->Dictionary:
	var audio_data:Dictionary = {}
	audio_data["Master"] = VolumeMaster
	audio_data["Music"] = VolumeMusic
	audio_data["SFX"] = VolumeSFX
	return audio_data

func set_audio_data(audio:Dictionary)->void:
	set_volume_master(audio.Master)
	set_volume_music(audio.Music)
	set_volume_sfx(audio.SFX)

