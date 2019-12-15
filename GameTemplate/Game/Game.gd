extends Node2D

signal SceneIsLoaded

enum {IDLE, FADEOUT, FADEIN}
export (String, FILE, "*.tscn") var First_Level: String
onready var CurrentScene = $Levels.get_child($Levels.get_child_count() - 1)
var NextScene
var FadeState:int = IDLE

func _ready()->void:
	Event.connect("NewGame",	self, "on_New_game")
	Event.connect("Options",	self, "on_Options")
	Event.connect("Exit",		self, "on_Exit")
	Event.connect("ChangeScene",self, "on_ChangeScene")
	#Background loader
	SceneLoader.connect("scene_loaded", self, "on_scene_loaded")
	#SceneLoader.load_scene("res://Levels/TestScene.tscn", {instructions="for what reason it got loaded"})

func on_ChangeScene(scene):
	if FadeState != IDLE:
		return
	#print("on_ChangeScene: ", scene)
	SceneLoader.load_scene(scene, {scene="Level"})
	FadeState = FADEOUT
	$FadeTween.interpolate_property($FadeLayer, "percent", 0.0, 1.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
	$FadeTween.start()

func on_New_game()->void:	#Handle first level logic
	Event.emit_signal("ChangeScene", First_Level)

func on_Options()->void:
	if FadeState != IDLE:
		return
	$PauseLayer/MainOptions.show = true
	#get_tree().paused = true

func on_Exit()->void:
	if FadeState != IDLE:
		return
	get_tree().quit()

func on_scene_loaded(Loaded)->void:
	NextScene = Loaded.resource.instance()
	emit_signal("SceneIsLoaded")	#Scene fade signal in case it loads longer than fade out

func change_scene()->void: #handle actual scene change
	if NextScene == null:
		return
	print("change_scene: ", NextScene) #ERROR InputMouseButton something
	yield(get_tree(), "idle_frame") #continue on idle frame
	CurrentScene.free()
	CurrentScene = NextScene
	NextScene = null
	$Levels.add_child(CurrentScene)

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
			$FadeTween.interpolate_property($FadeLayer, "percent", 1.0, 0.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
			$FadeTween.start()
		FADEIN:
			FadeState = IDLE
	
