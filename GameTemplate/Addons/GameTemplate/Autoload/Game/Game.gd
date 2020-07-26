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

func _ready()->void:
	MenuEvent.connect("Options",	self, "on_Options")
	connect("Exit",		self, "on_Exit")
	connect("ChangeScene",self, "on_ChangeScene")
	connect("Restart", 	self, "restart_scene")
	#Background async loader
	SceneLoader.connect("scene_loaded", self, "on_scene_loaded")
	GuiBrain.gui_collect_focusgroup()

func on_ChangeScene(scene)->void:
	if FadeState != IDLE:
		return
	if Settings.HTML5:
		NextScene = load(scene)
	else:
		SceneLoader.load_scene(scene, {scene="Level"})
	FadeState = FADEOUT
	$FadeLayer/FadeTween.interpolate_property($FadeLayer, "percent", 0.0, 1.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
	$FadeLayer/FadeTween.start()

func on_Exit()->void:
	if FadeState != IDLE:
		return
	get_tree().quit()

func on_scene_loaded(Loaded)->void:
	if Loaded.resource == null:
		print(' Game.gd 45 - Loaded.resource is null')
	NextScene = Loaded.resource
	emit_signal("SceneIsLoaded")	#Scene fade signal in case it loads longer than fade out

func change_scene()->void: #handle actual scene change
	if NextScene == null:
		return
	print("change_scene: ", NextScene) #ERROR InputMouseButton something
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
			change_scene()
			FadeState = FADEIN
			$FadeLayer/FadeTween.interpolate_property($FadeLayer, "percent", 1.0, 0.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
			$FadeLayer/FadeTween.start()
		FADEIN:
			FadeState = IDLE

