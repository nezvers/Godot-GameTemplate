class_name FileDialogManager
extends FileDialog

## Emited when user made a choice and that is available in file_path_list
signal selected

## One place for single file, multiple file or directory choice
var file_path_list:PackedStringArray

var is_web:bool
var js_upload_interface_dict:Dictionary

func _ready()->void:
	file_selected.connect(on_desktop_file_selected)
	files_selected.connect(on_desktop_files_selected)
	dir_selected.connect(on_desktop_dir_selected)


## extension_array = ["*.res ; Project Resource"]
func desktop_choose_file(_title:String, _ok_button_text:String, _file_mode:FileMode, extension_array:Array[String])->void:
	if visible:
		print("DesktopFileDialog [INFO]: already active")
		return
	
	file_mode = _file_mode
	current_file = ""
	title = _title
	ok_button_text = _ok_button_text
	set_filters(PackedStringArray(extension_array))
	show()

func on_desktop_file_selected(path:String)->void:
	file_path_list = PackedStringArray([path])
	selected.emit()

func on_desktop_files_selected(path_list:PackedStringArray)->void:
	file_path_list = path_list
	selected.emit()

func on_desktop_dir_selected(path:String)->void:
	file_path_list = PackedStringArray([path])
	selected.emit()


## images = "image/png, image/jpeg, image/webp"
## binary = "application/prs.binary"
func web_chose_open_file(js_interface_name:String = "_open_file", file_signature:String = "application/prs.binary", temp_filepath:String = "user://temp_file.res")->void:
	if !js_upload_interface_dict.has(js_interface_name):
		JavascriptFileDialog.define_upload_interface(js_interface_name, file_signature)
	
	var js_callback:JavaScriptObject = JavaScriptBridge.create_callback(web_open_file_complete.bind(temp_filepath))
	var js_interface:JavaScriptObject = JavaScriptBridge.get_interface(js_interface_name)
	js_interface.upload(js_callback)

## Loaded file is a basically PackedByteArray.
## To actually use, it needs to be turned into a file on a browsers sandbox storage.
## From that you can use a file path to load a resource.
## TODO: Cache file paths to later free the storage
func web_open_file_complete(args:Array, temp_filepath:String)->void:
	var _obj:JavaScriptObject = args[1]
	if _obj.length < 1:
		return
	
	if FileAccess.file_exists(temp_filepath):
		DirAccess.remove_absolute(temp_filepath)
	
	var _buffer: = JavascriptFileDialog.Uint8Array_to_PackedByteArray(args[1])
	var _file = FileAccess.open(temp_filepath, FileAccess.WRITE_READ)
	_file.store_buffer(_buffer)
	
	if !FileAccess.file_exists(temp_filepath):
		return
	file_path_list = PackedStringArray([temp_filepath])
	selected.emit()

func web_save_file_complete(args:Array, temp_filepath:String)->void:
	pass

## Second argument is PackedByteArray that is used as load from buffer
func web_open_image_complete(args:Array, temp_filepath:String)->void:
	var _buffer: = JavascriptFileDialog.Uint8Array_to_PackedByteArray(args[1])
	var _image: = Image.new()
	var _image_error:int
	match args[0]:
		"image/png":
			_image_error = _image.load_png_from_buffer(_buffer)
		"image/jpeg":
			_image_error = _image.load_jpg_from_buffer(_buffer)
		"image/webp":
			_image_error = _image.load_webp_from_buffer(_buffer)
		_:
			print("Unsupported file format - %s." % args[0])
			return
	if _image_error:
		print("An error occurred while trying to display the image.")
		return
