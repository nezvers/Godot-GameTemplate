extends Node

var log_path:String = "user://log_file.txt"

func _ready()->void:
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	var _log_txt:FileAccess = FileAccess.open(log_path, FileAccess.WRITE)

func log_file(text:String)->void:
	if !FileAccess.file_exists(log_path):
		return
	var log_txt:FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE)
	log_txt.seek_end(0)
	log_txt.store_line(text)
