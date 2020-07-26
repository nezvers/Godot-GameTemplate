extends Node

#OS
var HTML5:bool = false

func _ready()->void:
	if OS.get_name() == "HTML5":
		HTML5 = true
	SettingsLanguage.add_translations()											#TO-DO need a way to add translations to project through the plugin
	SettingsResolution.get_resolution()
	SettingsSaveLoad.load_settings()
	SettingsAudio.get_volumes()
	SettingsControls.get_controls()
	#SettingsSaveLoad.save_settings()		#Call this method to trigger Settings saving

