## https://godotsteam.com/tutorials/initializing/
extends Node

var app_id:int = 480 # Steam test app - Spacewar

## Steam singleton reference saved to a variable because when steam implementation is taken out there's errors when reffering to Steam
var steam_singleton:Object

var is_on_steam_deck: bool
var is_online: bool
var is_owned: bool

## user's steam id
var steam_id: int

var steam_username: String

func _ready()->void:
	set_process(false)
	if !Engine.has_singleton("Steam"):
		return
	
	OS.set_environment("SteamAppId", str(app_id))
	OS.set_environment("SteamGameId", str(app_id))
	
	var initialize_response: Dictionary = Steam.steamInitEx( true, app_id )
	print("SteamInit [INFO]: Steam initialize - %s " % initialize_response)
	
	if initialize_response["status"] > 0:
		printerr("SteamInit [ERROR]: Failed to initialize Steam, shutting down: %s" % initialize_response)
		printerr("Steam must be running in background")
		get_tree().quit()
	
	steam_singleton = Engine.get_singleton("Steam")
	
	if steam_singleton == null:
		printerr("SteamInit [ERROR]: failed to get Steam singleton")
		get_tree().quit()
	var is_on_steam_deck = steam_singleton.isSteamRunningOnSteamDeck()
	var is_online = steam_singleton.loggedOn()
	var is_owned = steam_singleton.isSubscribed()
	var steam_id = steam_singleton.getSteamID()
	var steam_username = steam_singleton.getPersonaName()
	
	if is_owned == false:
		printerr("SteamInit [ERROR]: User does not own this game")
		get_tree().quit()
	
	SaveableResource.set_save_type( SaveableResource.SaveType.STEAM)
	set_process(true)


func _process(_delta: float) -> void:
	steam_singleton.run_callbacks()
