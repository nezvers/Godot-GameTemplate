extends VBoxContainer

onready var Master:HSlider = find_node("Master").get_node("HSlider")
onready var Music:HSlider = find_node("Music").get_node("HSlider")
onready var SFX:HSlider = find_node("SFX").get_node("HSlider")
onready var Resolution_panel:Panel = find_node("Panel")
onready var Volume_panel:Panel = find_node("Panel2")
onready var Language_panel:Panel = find_node("Panel3")
var SetUp:bool = true #need to disable playing sound on initiating faders

func _ready()->void:
	#Set up toggles and sliders
	if Settings.HTML5:
		find_node("Borderless").visible = false
		find_node("Scale").visible = false
	set_resolution()
	set_volume_sliders()
	MenuEvent.Languages = false #just in case project saved with visible Languages
	
	SetUp = false #Finished fader setup
	MenuEvent.connect("Controls", self, "on_show_controls")
	MenuEvent.connect("Languages", self, "on_show_languages")
	Settings.connect("Resized", self, "_on_Resized")
	#Localization
	Settings.connect("ReTranslate", self, "retranslate")
	retranslate()

func set_resolution()->void:
	find_node("Fullscreen").pressed = Settings.Fullscreen
	find_node("Borderless").pressed = Settings.Borderless
	#Your logic for scaling

func set_volume_sliders()->void: #Initialize volume sliders
	Master.value = Settings.VolumeMaster * 100
	Music.value = Settings.VolumeMusic * 100
	SFX.value = Settings.VolumeSFX * 100

#### BUTTON SIGNALS ####
func _on_Master_value_changed(value)->void:
	if SetUp:
		return
	Settings.VolumeMaster = value/100
	var player:AudioStreamPlayer = find_node("Master").get_node("AudioStreamPlayer")
	player.stream = PreLoad.snd_TestBeep
	player.play()

func _on_Music_value_changed(value)->void:
	if SetUp:
		return
	Settings.VolumeMusic = value/100
	var player:AudioStreamPlayer = find_node("Music").get_node("AudioStreamPlayer")
	player.stream = PreLoad.snd_TestBeep
	player.play()

func _on_SFX_value_changed(value)->void:
	if SetUp:
		return
	Settings.VolumeSFX = value/100
	var player:AudioStreamPlayer = find_node("SFX").get_node("AudioStreamPlayer")
	player.stream = PreLoad.snd_TestBeep
	player.play()

func _on_Fullscreen_pressed()->void:
	if SetUp:
		return
	Settings.Fullscreen = find_node("Fullscreen").pressed

func _on_Borderless_pressed()->void:
	if SetUp:
		return
	Settings.Borderless = find_node("Borderless").pressed

func _on_ScaleUp_pressed()->void:
	Settings.Scale += 1

func _on_ScaleDown_pressed()->void:
	Settings.Scale -= 1

func _on_Resized()->void:
	set_resolution()

func _on_Controls_pressed()->void:
	MenuEvent.Controls = true

func _on_Back_pressed()->void:
	Settings.save_settings()
	MenuEvent.Options = false

func _on_Languages_pressed()->void:
	MenuEvent.Languages = !MenuEvent.Languages
	if !MenuEvent.Languages:
		return
	yield(Settings, "ReTranslate") #After choosing language it will trigger ReTranslate
	print("Language_choosen")
	MenuEvent.Languages = !MenuEvent.Languages

#EVENT SIGNALS
func on_show_controls(value:bool)->void:
	visible = !value 	#because showing controls

func on_show_languages(value:bool)->void:
	Resolution_panel.visible = !value
	Volume_panel.visible = !value

#Localization
func retranslate()->void:
	find_node("Resolution").text = tr("RESOLUTION")
	find_node("Volume").text = tr("VOLUME")
	get_node("HBoxContainer/Panel3/VBoxContainer/Languages").text = tr("LANGUAGES")
	find_node("Fullscreen").text = tr("FULLSCREEN")
	find_node("Borderless").text = tr("BORDERLESS")
	find_node("Scale").text = tr("SCALE")
	find_node("Master").get_node("ScaleName").text = tr("MASTER")
	find_node("Music").get_node("ScaleName").text = tr("MUSIC")
	find_node("SFX").get_node("ScaleName").text = tr("SFX")
	get_node("MarginContainer/VBoxContainer/Languages").text = tr("LANGUAGES")
	find_node("Controls").text = tr("CONTROLS")
	find_node("Back").text = tr("BACK")

func set_node_in_focus()->void:
	var FocusGroup:Array = get_groups()
