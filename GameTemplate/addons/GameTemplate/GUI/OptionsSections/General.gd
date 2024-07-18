extends VBoxContainer

#RESOLUTION
@onready var Resolution_panel:Panel = find_child("Panel")
@onready var Volume_panel:Panel = find_child("Panel2")
@onready var Language_panel:Panel = find_child("Panel3")
#AUDIO
@onready var Master_slider:HSlider = find_child("Master").get_node("HSlider")
@onready var Music_slider:HSlider = find_child("Music").get_node("HSlider")
@onready var SFX_slider:HSlider = find_child("SFX").get_node("HSlider")
@onready var Master_player:AudioStreamPlayer = find_child("Master").get_node("AudioStreamPlayer")
@onready var Music_player:AudioStreamPlayer = find_child("Music").get_node("AudioStreamPlayer")
@onready var SFX_player:AudioStreamPlayer = find_child("SFX").get_node("AudioStreamPlayer")
var beep: = preload("res://addons/GameTemplate/Assets/Sounds/TestBeep.wav")

func _ready()->void:
	#Set up toggles and sliders
	if Settings.HTML5:
		find_child("Borderless").visible = false
		find_child("Scale").visible = false
	set_resolution()
	set_volume_sliders()
	
	MenuEvent.connect("ControlsSignal", on_show_controls)
	MenuEvent.connect("LanguagesSignal", on_show_languages)
	SettingsResolution.connect("Resized", _on_Resized)
	#Localization
	SettingsLanguage.connect("ReTranslate", retranslate)
	retranslate()

func set_resolution()->void:
	find_child("Fullscreen").button_pressed = SettingsResolution.Fullscreen
	find_child("Borderless").button_pressed = SettingsResolution.Borderless
	#Your logic for scaling

func set_volume_sliders()->void: #Initialize volume sliders
	Master_slider.value = SettingsAudio.VolumeMaster * 100
	Music_slider.value = SettingsAudio.VolumeMusic * 100
	SFX_slider.value = SettingsAudio.VolumeSFX * 100
	Master_player.stream = beep
	Music_player.stream = beep
	SFX_player.stream = beep

#### BUTTON SIGNALS ####
func _on_Master_value_changed(value)->void:
	SettingsAudio.VolumeMaster = value/100
	var player:AudioStreamPlayer = find_child("Master").get_node("AudioStreamPlayer")
	player.play()

func _on_Music_value_changed(value)->void:
	SettingsAudio.VolumeMusic = value/100
	var player:AudioStreamPlayer = find_child("Music").get_node("AudioStreamPlayer")
	player.play()

func _on_SFX_value_changed(value)->void:
	SettingsAudio.VolumeSFX = value/100
	var player:AudioStreamPlayer = find_child("SFX").get_node("AudioStreamPlayer")
	player.play()

func _on_Fullscreen_pressed()->void:
	SettingsResolution.set_fullscreen(find_child("Fullscreen").button_pressed)

func _on_Borderless_pressed()->void:
	SettingsResolution.set_borderless(find_child("Borderless").button_pressed)

func _on_ScaleUp_pressed()->void:
	SettingsResolution.Scale += 1

func _on_ScaleDown_pressed()->void:
	SettingsResolution.Scale -= 1

func _on_Resized()->void:
	set_resolution()

func _on_Controls_pressed()->void:
	MenuEvent.Controls_val = true

func _on_Back_pressed()->void:
	SettingsSaveLoad.save_settings()
	MenuEvent.Options_val = false
	if PauseMenu.can_show:
		get_tree().get_nodes_in_group("Pause")[0].grab_focus()


func _on_Languages_pressed()->void:
	MenuEvent.Languages_val = true

#EVENT SIGNALS
func on_show_controls(value:bool)->void:
	visible = !value 	#because showing controls
	if visible:
		get_tree().get_nodes_in_group("General")[0].grab_focus()

func on_show_languages(value:bool)->void:
	visible = !value
	if visible:
		get_tree().get_nodes_in_group("General")[0].grab_focus()

#Localization
func retranslate()->void:
	find_child("Resolution").text 					= tr("RESOLUTION")
	find_child("Volume").text 						= tr("VOLUME")
	find_child("Fullscreen").text 					= tr("FULLSCREEN")
	find_child("Borderless").text 					= tr("BORDERLESS")
	find_child("Scale").text 						= tr("SCALE")
	find_child("Master").get_node("ScaleName").text	= tr("MASTER")
	find_child("Music").get_node("ScaleName").text 	= tr("MUSIC")
	find_child("SFX").get_node("ScaleName").text 	= tr("SFX")
	find_child("LanguagesButton").text 				= tr("LANGUAGES")
	find_child("Controls").text 						= tr("CONTROLS")
	find_child("Back").text 							= tr("BACK")

func set_node_in_focus()->void:
	var FocusGroup:Array = get_groups()
