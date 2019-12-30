extends VBoxContainer

onready var Master:HSlider = find_node("Master").get_node("HSlider")
onready var Music:HSlider = find_node("Music").get_node("HSlider")
onready var SFX:HSlider = find_node("SFX").get_node("HSlider")
var SetUp:bool = true

func _ready()->void:
	#Set up toggles and sliders
	if Settings.HTML5:
		find_node("Borderless").visible = false
		find_node("Scale").visible = false
	set_resolution()
	set_volume_sliders()
	#set_button_list()
	SetUp = false
	Settings.connect("Resized", self, "_on_Resized")

func set_resolution()->void:
	find_node("Fullscreen").pressed = Settings.Fullscreen
	find_node("Borderless").pressed = Settings.Borderless
	#Your logic for scaling

func set_volume_sliders()->void:
	Master.value = Settings.VolumeMaster * 100
	Music.value = Settings.VolumeMusic * 100
	SFX.value = Settings.VolumeSFX * 100

#### SIGNALS ####
func _on_Master_value_changed(value):
	if SetUp:
		return
	Settings.VolumeMaster = value/100
	var player:AudioStreamPlayer = find_node("Master").get_node("AudioStreamPlayer")
	player.stream = pre_load.snd_TestBeep
	player.play()

func _on_Music_value_changed(value):
	if SetUp:
		return
	Settings.VolumeMusic = value/100
	var player:AudioStreamPlayer = find_node("Music").get_node("AudioStreamPlayer")
	player.stream = pre_load.snd_TestBeep
	player.play()

func _on_SFX_value_changed(value):
	if SetUp:
		return
	Settings.VolumeSFX = value/100
	var player:AudioStreamPlayer = find_node("SFX").get_node("AudioStreamPlayer")
	player.stream = pre_load.snd_TestBeep
	player.play()

func _on_Fullscreen_pressed():
	if SetUp:
		return
	Settings.Fullscreen = find_node("Fullscreen").pressed

func _on_Borderless_pressed():
	if SetUp:
		return
	Settings.Borderless = find_node("Borderless").pressed

func _on_ScaleUp_pressed():
	Settings.Scale += 1

func _on_ScaleDown_pressed():
	Settings.Scale -= 1

func _on_Resized()->void:
	set_resolution()

func _on_Controls_pressed():
	visible = false
	get_node("../OptionsControls").visible = true

func _on_Back_pressed():
	Settings.save_settings()
	owner.set_show(false)
