extends Node
## Containers holding sliders. Their name should represent audio bus names.
@export var slider_container:Array[Node]

## Resource controlling audio settings
@export var audio_settings_resource:AudioSettingsResource
@export var save_button:Button


func _ready()->void:
	audio_settings_resource.load_resource()
	save_button.pressed.connect(save)
	update_sliders()
	for node in slider_container:
		var _bus_name: = node.name
		var _slider:Slider = node.get_node("Slider")
		_slider.value_changed.connect(on_drag_end.bind(_bus_name, _slider))

## Position sliders values
func update_sliders()->void:
	for node in slider_container:
		var _bus_name: = node.name
		var _slider: = node.get_node("Slider")
		_slider.set_value(audio_settings_resource.get_bus_volume(_bus_name))

## callback for slider drag end
func on_drag_end(_new_value: float, _bus_name:String, slider:Slider)->void:
	audio_settings_resource.set_bus_volume(_bus_name, slider.value)

## callback for slider value change
func on_value_changed(value:float, _bus_name:String, slider:Slider)->void:
	audio_settings_resource.set_bus_volume(_bus_name, slider.value)

func save()->void:
	audio_settings_resource.save_resource()
