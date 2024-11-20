extends Button

@export var file_dialog:FileDialogManager
@export var cache_mode:ResourceLoader.CacheMode

func _ready()->void:
	file_dialog.selected.connect(on_selected)

func _pressed()->void:
	file_dialog.desktop_choose_file("open", "open", FileDialog.FileMode.FILE_MODE_OPEN_FILE, [])

func on_selected()->void:
	# Use selected files or directories
	print(file_dialog.file_path_list)
