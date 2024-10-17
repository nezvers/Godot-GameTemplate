class_name JavascriptFileDialog
extends Node

# https://github.com/Pukkah/HTML5-File-Exchange-for-Godot/blob/master/addons/HTML5FileExchange/HTML5FileExchange.gd
# https://gist.github.com/nisovin/f230240003bbc404d203a88f78bd39a0

const upload_template:String = """
	var {0} = {};
	{0}.result = null;
	{0}.upload = function(gd_callback) {
		canceled = true;
		var input = document.createElement('INPUT'); 
		input.setAttribute("type", "file");
		input.setAttribute("accept", "{1}");
		input.click();
		input.addEventListener('change', event => {
			if (event.target.files.length > 0){
				console.log("cancelled file choice");
				canceled = false;}
			var file = event.target.files[0];
			var reader = new FileReader();
			this.fileType = file.type;
			// var fileName = file.name;
			reader.readAsArrayBuffer(file);
			reader.onloadend = (evt) => { // Since here's it's arrow function, "this" still refers to _HTML5FileExchange
				if (evt.target.readyState == FileReader.DONE) {
					this.result = new Uint8Array(evt.target.result);
					gd_callback(this.fileType, this.result); // It's hard to retrieve value from callback argument, so it's just for notification
				}
			}
		  });
	}
	"""

## ("_open_sprite", "image/png, image/jpeg, image/webp")
static func define_upload_interface(i_name:String, file_format:String)->void:
	var interface_definition:String = upload_template.format([i_name, file_format])
	#Define JS script
	JavaScriptBridge.eval(interface_definition, true)

static func Uint8Array_to_PackedByteArray(obj:JavaScriptObject)->PackedByteArray:
	var buffer: = PackedByteArray()
	buffer.resize(obj.length)
	for i in obj.length:
		buffer[i] = obj[i]
	return buffer
