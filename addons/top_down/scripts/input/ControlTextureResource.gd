class_name ControlTextureResource
extends Resource

@export var value:Array[InputTextureResource]

var dictionary:Dictionary
var is_initialized:bool

func initialize()->void:
	if is_initialized:
		return
	is_initialized = true
	for _input_texture:InputTextureResource in value:
		var _key:String = _get_key(_input_texture.event)
		dictionary[_key] = _input_texture.texture

## Retrieves Texture that matches InputEvent.
## Requires to be initialized before calling this function
func get_texture(event:InputEvent)->Texture:
	if event == null:
		return null
	
	var _key:String = _get_key(event)
	if !dictionary.has(_key):
		return null
	
	return dictionary[_key]

## Get string key to represent InputEvent
func _get_key(event:InputEvent)->String:
	if event is InputEventKey:
		var _key:String = event.as_text_key_label()
		if event.key_label != 0:
			#print("ControlTextureResource [INFO]: key_label - ", event.as_text_key_label())
			return event.as_text_key_label()
		if event.keycode != 0:
			#print("ControlTextureResource [INFO]: keycode - ", event.as_text_keycode())
			return event.as_text_keycode()
		if event.physical_keycode != 0:
			#print("ControlTextureResource [INFO]: physical_keycode - ", event.as_text_physical_keycode())
			return event.as_text_physical_keycode()
	#print("ControlTextureResource [INFO]: as_text ", event.as_text())
	return event.as_text()
