extends Button

@export var file_dialog:FileDialogManager
@export var cache_mode:ResourceLoader.CacheMode

func _pressed()->void:
	file_dialog.desktop_choose_file("open", "open", FileDialog.FileMode.FILE_MODE_OPEN_FILE, [])
