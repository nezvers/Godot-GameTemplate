extends CanvasLayer

var show:bool = false setget set_show
onready var Master:HSlider = get_node("Main_Options/Margin/Main/HBoxContainer/Panel2/VBoxContainer/HBoxContainer/Resolution/Master/HSlider")
onready var Music:HSlider = get_node("Main_Options/Margin/Main/HBoxContainer/Panel2/VBoxContainer/HBoxContainer/Resolution/Music/HSlider")
onready var SFX:HSlider = get_node("Main_Options/Margin/Main/HBoxContainer/Panel2/VBoxContainer/HBoxContainer/Resolution/SFX/HSlider")
var SetUp:bool = true

func _ready()->void:
	set_show(false)
	#show main section and hide controls
	$"Main_Options/Margin/Main".visible = true
	$"Main_Options/Margin/Controls".visible = false
	#Set up toggles and sliders
	set_resolution()
	set_volume_sliders()
	set_button_list()
	SetUp = false
	Settings.connect("Resized", self, "_on_Resized")

func set_show(value:bool)->void:
	show=value
	$Main_Options.visible = show
	$Main_Options/Margin/Main.visible = true
	if !Event.Paused:
		get_tree().paused = value

func _on_Back_pressed()->void:
	set_show(false)

func _on_Controls_pressed()->void:
	$"Main_Options/Margin/Main".visible = false
	$"Main_Options/Margin/Controls".visible = true


func _on_ControlsBack_pressed()->void:
	$"Main_Options/Margin/Main".visible = true
	$"Main_Options/Margin/Controls".visible = false

func set_resolution()->void:
	find_node("Fullscreen").pressed = Settings.Fullscreen
	find_node("Borderless").pressed = Settings.Borderless
	#Your logic for scaling

func set_volume_sliders()->void:
	Master.value = Settings.VolumeMaster * 100
	Music.value = Settings.VolumeMusic * 100
	SFX.value = Settings.VolumeSFX * 100

func set_button_list()->void:
	var ButtonList:VBoxContainer = $"Main_Options/Margin/Controls/Section/HBoxContainer/ScrollContainer/ButtonList"
	var aButton:PackedScene = load("res://GUI/ControlsButtons.tscn")
	var CheckList:Array = ['move_right', 'move_left', 'move_up', 'move_down', 'jump']
	var ActionList:Array = InputMap.get_actions()
	
	for action in ActionList:
		if action in CheckList:
			var ActionButtons:Array = InputMap.get_action_list(action)
			var ButtonInList:HBoxContainer = aButton.instance()
			ButtonList.add_child(ButtonInList)
			ButtonInList.get_node("ActionName").text = action
			ButtonInList.get_node("AssignedButton").text = get_button_names(ActionButtons)

func get_button_names(ActionButtons:Array)->String:
	var name:String = ""
	var index:int = 0
	var size = ActionButtons.size() -1
	for button in ActionButtons:
		name += " \"" + button.as_text() + "\""
		if index < size:
			name += ", "
		index += 1
	return name



#### SIGNALS ####
func _on_Master_value_changed(value):
	if SetUp:
		return
	Settings.VolumeMaster = value/100
	var player:AudioStreamPlayer = $"Main_Options/Margin/Main/HBoxContainer/Panel2/VBoxContainer/HBoxContainer/Resolution/Master/AudioStreamPlayer"
	player.stream = pre_load.snd_TestBeep
	player.play()

func _on_Music_value_changed(value):
	if SetUp:
		return
	Settings.VolumeMusic = value/100
	var player:AudioStreamPlayer = $"Main_Options/Margin/Main/HBoxContainer/Panel2/VBoxContainer/HBoxContainer/Resolution/Music/AudioStreamPlayer"
	player.stream = pre_load.snd_TestBeep
	player.play()

func _on_SFX_value_changed(value):
	if SetUp:
		return
	Settings.VolumeSFX = value/100
	var player:AudioStreamPlayer = $"Main_Options/Margin/Main/HBoxContainer/Panel2/VBoxContainer/HBoxContainer/Resolution/SFX/AudioStreamPlayer"
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