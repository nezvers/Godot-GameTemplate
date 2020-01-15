extends Node2D

signal SceneIsLoaded

enum {IDLE, FADEOUT, FADEIN}

onready var CurrentScene = null
onready var CurrentSceneInstance = $Levels.get_child($Levels.get_child_count() - 1)
var NextScene
var FadeState:int = IDLE

func _ready()->void:
	Event.connect("Options",	self, "on_Options")
	Event.connect("Exit",		self, "on_Exit")
	Event.connect("ChangeScene",self, "on_ChangeScene")
	Event.connect("Restart", 	self, "restart_scene")
	#Background loader
	SceneLoader.connect("scene_loaded", self, "on_scene_loaded")
	#SceneLoader.load_scene("res://Levels/TestScene.tscn", {instructions="for what reason it got loaded"})
	guiBrain.gui_collect_focusgroup()

func on_ChangeScene(scene):
	if FadeState != IDLE:
		return
	#print("on_ChangeScene: ", scene)
	if Settings.HTML5:
		NextScene = load(scene)
	else:
		SceneLoader.load_scene(scene, {scene="Level"})
	FadeState = FADEOUT
	$FadeLayer/FadeTween.interpolate_property($FadeLayer, "percent", 0.0, 1.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
	$FadeLayer/FadeTween.start()

func on_Options()->void:
	if FadeState != IDLE:
		return
	$OptionsMenu.show = true
	#get_tree().paused = true

func on_Exit()->void:
	if FadeState != IDLE:
		return
	get_tree().quit()

func on_scene_loaded(Loaded)->void:
	NextScene = Loaded.resource
	emit_signal("SceneIsLoaded")	#Scene fade signal in case it loads longer than fade out

func change_scene()->void: #handle actual scene change
	if NextScene == null:
		return
	print("change_scene: ", NextScene) #ERROR InputMouseButton something
	yield(get_tree(), "idle_frame") #continue on idle frame
	CurrentSceneInstance.free()
	CurrentScene = NextScene
	NextScene = null
	CurrentSceneInstance = CurrentScene.instance()
	$Levels.add_child(CurrentSceneInstance)

func restart_scene():
	if FadeState != IDLE:
		return
	yield(get_tree(), "idle_frame")
	CurrentSceneInstance.free()
	CurrentSceneInstance = CurrentScene.instance()
	$Levels.add_child(CurrentSceneInstance)

func _on_FadeTween_tween_completed(object, key)->void:
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
	
