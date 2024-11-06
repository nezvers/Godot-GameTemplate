extends AudioStreamPlayer

@export var music_playlist:DictionaryResource
@export var pause_resource:BoolResource
@export var automatic_loop:bool = true

func _ready()->void:
	pause_resource.updated.connect(pause_changed)

func pause_changed()->void:
	var music_id:int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_effect_enabled(music_id, 0, pause_resource.value)

func start(song_name:String)->void:
	if !music_playlist.value.has(song_name):
		printerr("Music [INFO]: No song with a name - ", song_name)
		return
	
	var music_path:String = music_playlist.value[song_name]
	if stream != null && stream.resource_path == music_path:
		if !playing:
			start_music()
		return
	print("Music [INFO]: start - ", song_name, ": ", music_path)
	load_play(music_path)

func load_play(path:String)->void:
	var music_stream:AudioStream = load(path)
	if music_stream == null:
		printerr("Music [INFO]: music stream didn't load - ", path)
		return
	## To bypass need to enable loop for each music.
	## And allow not to include .import files in git
	stream = music_stream
	if "loop" in stream && automatic_loop:
		stream.loop = true
	start_music()

func start_music()->void:
	play(0.0)
