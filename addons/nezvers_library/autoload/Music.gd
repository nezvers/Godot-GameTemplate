extends AudioStreamPlayer

@export var music_playlist:DictionaryResource
@export var pause_resource:BoolResource

func _ready()->void:
	pause_resource.updated.connect(pause_changed)

func pause_changed()->void:
	var music_id:int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_effect_enabled(music_id, 0, pause_resource.value)

func start(song_name:String)->void:
	if !music_playlist.value.has(song_name):
		printerr("Music Manager: No song with a name - ", song_name)
		return
	
	var music_path:String = music_playlist.value[song_name]
	if stream != null && stream.resource_path == music_path:
		if !playing:
			start_music()
		return
	print("Music Manager: start - ", song_name, ": ", music_path)
	load_play(music_path)

func load_play(path:String)->void:
	var music_stream:AudioStream = load(path)
	if music_stream == null:
		printerr("MusicManager: music stream didn't load - ", path)
		return
	stream = music_stream
	start_music()

func start_music()->void:
	play(0.0)
