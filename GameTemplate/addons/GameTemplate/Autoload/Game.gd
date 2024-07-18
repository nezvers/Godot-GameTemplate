extends Node2D

signal NewGame		#You choose how to use it
signal Continue		#You choose how to use it
signal Resume		#You choose how to use it
signal Restart		#Reloads current scene
signal ChangeScene	#Pass location of next scene file
signal Exit			#Triggers closing the game

@onready var CurrentScene = null
var NextScene

var loader: = ResourceAsyncLoader.new()

func _ready()->void:
	connect("Exit", on_Exit)
	connect("ChangeScene", on_ChangeScene)
	connect("Restart", restart_scene)

func on_ChangeScene(scene)->void:
	if ScreenFade.state != ScreenFade.fade_type.IDLE:
		return
	ScreenFade.state = ScreenFade.fade_type.OUT
	if loader.can_async:
		var a = await loader.load_start( [scene] )
		NextScene = a[0]				#Using ResourceAsyncLoader to load in next scene - it takes in array list and gives back array
	else:
		var a = await loader.load_start( [scene] )
		NextScene = a[0]
	if NextScene == null:
		print(' Game.gd 36 - Loaded.resource is null')
		return
	if ScreenFade.state != ScreenFade.fade_type.BLACK:
		await ScreenFade.fade_complete
	switch_scene()
	ScreenFade.state = ScreenFade.fade_type.IN

func switch_scene()->void: 														#handles actual scene change
	CurrentScene = NextScene
	NextScene = null
	get_tree().change_scene_to_packed(CurrentScene)

func restart_scene()->void:
	get_tree().reload_current_scene()


func on_Exit()->void:
	if ScreenFade.state != ScreenFade.fade_type.IDLE:
		return
	get_tree().quit()
