extends Node


#var Save / Load
const CONFIG_DIR: = "user://saves/" #"user://saves/"
const CONFIG_FILE_NAME: = "settings"
const CONFIG_EXTENSION: = ".tres"

#Save/ Load
#Call this method to trigger Settings saving - by default triggered on closing options menu
func save_settings()->void:
	save_settings_resource()
	#save_settings_JSON()

func load_settings()->bool:
	var loaded:bool
	loaded = load_settings_resource()
	#loaded = load_settings_JSON()
	return loaded



# Resource VARIATION - new version
func save_settings_resource()->void:
	var new_save: 			= SaveSettings.new()
	new_save.resolution 	= SettingsResolution.get_resolution_data()
	new_save.audio			= SettingsAudio.get_audio_data()
	new_save.inputs 		= SettingsControls.get_input_data()
	new_save.language		= SettingsLanguage.get_language_data()
	
	var dir: = Directory.new()
	if not dir.dir_exists(CONFIG_DIR):
		dir.make_dir_recursive(CONFIG_DIR)
	ResourceSaver.save(CONFIG_DIR + CONFIG_FILE_NAME + CONFIG_EXTENSION, new_save)

func load_settings_resource()->bool:
	if !ResourceLoader.exists(CONFIG_DIR + CONFIG_FILE_NAME + CONFIG_EXTENSION):
		return false
	
	var new_load:Resource = ResourceLoader.load(CONFIG_DIR + CONFIG_FILE_NAME + CONFIG_EXTENSION, 'Resource', true)
	SettingsResolution.set_resolution_data(new_load.resolution)
	SettingsAudio.set_audio_data(new_load.audio)
	SettingsControls.set_input_data(new_load.inputs)
	SettingsLanguage.set_language(new_load.language)
	return true




# JSON VARIATION - Old version
func save_settings_JSON()->void:
	var dir: = Directory.new()
	if not dir.dir_exists(CONFIG_DIR):
		dir.make_dir_recursive(CONFIG_DIR)
	var SettingsSaver:File = File.new()
	SettingsSaver.open(CONFIG_DIR + CONFIG_FILE_NAME + ".save", File.WRITE)
	var save_data:Dictionary = get_save_data_JSON()
	SettingsSaver.store_line(to_json(save_data))
	SettingsSaver.close()

func load_settings_JSON()->bool:
	if Settings.HTML5: 										#need to confirm but for now means that HTML5 won't use the saving
		return	false
	#Json to Dictionary
	var SettingsLoader:File = File.new()
	if !SettingsLoader.file_exists(CONFIG_DIR + CONFIG_FILE_NAME + CONFIG_EXTENSION):
		return  false										#We don't have a save to load
	SettingsLoader.open(CONFIG_DIR + CONFIG_FILE_NAME + CONFIG_EXTENSION, File.READ)
	var save_data = parse_json(SettingsLoader.get_line())
	SettingsLoader.close()
	
	set_save_data_JSON(save_data)								#Dictionary to Settings
	return true

func get_save_data_JSON()->Dictionary:
	var savedata: = {
		inputs = SettingsControls.get_input_data(),
		resolution = SettingsResolution.get_resolution_data(),
		audio = SettingsAudio.get_audio_data(),
		language = {locale = SettingsLanguage.get_language_data()}
		}
	return savedata

func set_save_data_JSON(save_data:Dictionary)->void:
	SettingsControls.set_input_data(save_data.inputs)
	SettingsResolution.set_resolution_data(save_data.resolution)
	SettingsAudio.set_audio_data(save_data.audio)
	SettingsLanguage.set_language(save_data.language.locale)






