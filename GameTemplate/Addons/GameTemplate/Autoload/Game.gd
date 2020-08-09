extends Node2D

signal NewGame
signal Continue
signal Resume
signal Restart
signal ChangeScene
signal Exit

signal SceneIsLoaded	#used internally to trigger when new scene is loaded

export (String, FILE) var main_menu

onready var CurrentScene = null
onready var CurrentSceneInstance = get_tree().current_scene
var NextScene

var loader: = ResourceAsyncLoader_GT.new()

func _ready()->void:
	MenuEvent.connect("Options",	self, "on_Options")
	connect("Exit",			self, "on_Exit")
	connect("ChangeScene",	self, "on_ChangeScene")
	connect("Restart", 		self, "restart_scene")
	#Background async loader
	GuiBrain.gui_collect_focusgroup()

func on_ChangeScene(scene)->void:
	if ScreenFade.state != ScreenFade.IDLE:
		return

	ScreenFade.state = ScreenFade.OUT
	
	NextScene = yield(loader.load_start( [scene] ), "completed")[0]		#Using ResourceAsyncLoader_GT to load in next scene - it takes in array list and gives back array
	if NextScene == null:
		print(' Game.gd 36 - Loaded.resource is null')
		return
	
	
	if ScreenFade.state != ScreenFade.BLACK:
		yield(ScreenFade, "fade_complete")
		print("yielded ")
	
	switch_scene()
	ScreenFade.state = ScreenFade.IN

func switch_scene()->void: #handle actual scene change
	print("change_scene: ", NextScene)
	CurrentScene = NextScene
	NextScene = null
	get_tree().change_scene_to(CurrentScene)

func restart_scene()->void:
	if ScreenFade.state != ScreenFade.IDLE:
		return
	get_tree().reload_current_scene()


func on_Exit()->void:
	if ScreenFade.state != ScreenFade.IDLE:
		return
	get_tree().quit()

