extends Node


#var Save / Load
var CONFIG_FILE:String = "user://settings.save"
var Settings_loaded:bool = false


#Save/ Load
#Call this method to trigger Settings saving
func save_settings()->void:
	var SettingsSaver:File = File.new()
	SettingsSaver.open(CONFIG_FILE, File.WRITE)
	var save_data:Dictionary = get_save_data()
	SettingsSaver.store_line(to_json(save_data))
	SettingsSaver.close()

func load_settings()->void:
	if Settings.HTML5: 										#need to confirm but for now means that HTML5 won't use the method
		return
	#Json to Dictionary
	var SettingsLoader:File = File.new()
	if !SettingsLoader.file_exists(CONFIG_FILE):
		return  #We don't have a save to load
	Settings_loaded = true
	SettingsLoader.open(CONFIG_FILE, File.READ)
	var save_data
	save_data = parse_json(SettingsLoader.get_line())
	SettingsLoader.close()
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
	for action_name in SettingsControls.Actions:
		var button_list_data:Dictionary = {}
		var button_list:Array = SettingsControls.ActionControls[action_name]
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
		SettingsLanguage.set_language(save_data.language.locale)

func set_ActionControlls_default()->void:
	for action_name in SettingsControls.Actions:
		SettingsControls.ActionControls[action_name] = []

func set_input_data(inputs:Dictionary)->void:
	var action_names:Array = inputs.keys()
	for action_name in action_names:
		var button_names = inputs[action_name].keys()
		for button_name in button_names:
			var button = inputs[action_name][button_name]
			var event:InputEvent = set_button_data(button)
			SettingsControls.ActionControls[action_name].push_back(event)
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
	for action_name in SettingsControls.Actions:
		InputMap.action_erase_events(action_name)
		for event in SettingsControls.ActionControls[action_name]:
			InputMap.action_add_event(action_name, event)

func get_resolution_data()->Dictionary:
	var resolution_data:Dictionary = {}
	#resolution_data["Fullscreen"] = SettingsResolution.Fullscreen
	resolution_data["Borderless"] = SettingsResolution.Borderless
	resolution_data["Scale"] = SettingsResolution.Scale
	return resolution_data

func set_resolution_data(resolution:Dictionary)->void:
	#SettingsResolution.set_fullscreen(resolution.Fullscreen)
	SettingsResolution.set_borderless(resolution.Borderless)
	SettingsResolution.set_scale(resolution.Scale)

func get_audio_data()->Dictionary:
	var audio_data:Dictionary = {}
	audio_data["Master"] = SettingsAudio.VolumeMaster
	audio_data["Music"] = SettingsAudio.VolumeMusic
	audio_data["SFX"] = SettingsAudio.VolumeSFX
	return audio_data

func set_audio_data(audio:Dictionary)->void:
	SettingsAudio.set_volume_master(audio.Master)
	SettingsAudio.set_volume_music(audio.Music)
	SettingsAudio.set_volume_sfx(audio.SFX)

