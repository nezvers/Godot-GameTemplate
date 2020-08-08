extends Node2D

signal NewGame
signal Continue
signal Resume
signal Restart
signal ChangeScene
signal Exit

signal SceneIsLoaded	#used internally to trigger when new scene is loaded

export (String, FILE) var main_menu

enum {IDLE, FADEOUT, FADEIN}

onready var CurrentScene = null
onready var CurrentSceneInstance = get_tree().current_scene
var NextScene
var FadeState:int = IDLE

var loader: = ResourceAsyncLoader_GT.new()

func _ready()->void:
	MenuEvent.connect("Options",	self, "on_Options")
	connect("Exit",			self, "on_Exit")
	connect("ChangeScene",	self, "on_ChangeScene")
	connect("Restart", 		self, "restart_scene")
	#Background async loader
	GuiBrain.gui_collect_focusgroup()

func on_ChangeScene(scene)->void:
	if FadeState != IDLE:
		return

	FadeState = FADEOUT
	$FadeLayer/FadeTween.interpolate_property($FadeLayer, "percent", 0.0, 1.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
	$FadeLayer/FadeTween.start()
	
	NextScene = yield(loader.load_start( [scene] ), "completed")[0]		#Using ResourceAsyncLoader_GT to load in next scene - it takes in array list and gives back array
	if NextScene == null:
		print(' Game.gd 4q - Loaded.resource is null')
	emit_signal("SceneIsLoaded")	#Scene fade signal in case it loads longer than fade out

func switch_scene()->void: #handle actual scene change
	if NextScene == null:
		return
	print("change_scene: ", NextScene)
	CurrentScene = NextScene
	NextScene = null
	get_tree().change_scene_to(CurrentScene)

func restart_scene()->void:
	if FadeState != IDLE:
		return
	get_tree().reload_current_scene()

func _on_FadeTween_tween_completed(_object, _key)->void:
	match FadeState:
		IDLE:
			pass
		FADEOUT:
			if NextScene == null:
				print("Not loaded, please wait!")
				yield(self, "SceneIsLoaded")
			switch_scene()
			FadeState = FADEIN
			$FadeLayer/FadeTween.interpolate_property($FadeLayer, "percent", 1.0, 0.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
			$FadeLayer/FadeTween.start()
		FADEIN:
			FadeState = IDLE

func on_Exit()->void:
	if FadeState != IDLE:
		return
	get_tree().quit()

