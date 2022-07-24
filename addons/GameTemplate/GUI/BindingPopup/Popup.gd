extends Popup

signal NewControl

var NewEvent:InputEvent

func _ready()->void:
	popup_exclusive = true
	set_process_input(false)
	connect("about_to_show", self, "receive_input")
	connect("popup_hide", self, "receive_focus")
	#Localization
	SettingsLanguage.connect("ReTranslate", self, "retranslate")
	retranslate()

func receive_input()->void:
	set_process_input(true)

func receive_focus()->void:
	get_tree().get_nodes_in_group("ContainerFocus")[0].call_deferred("grab_focus")

func _input(event)->void:
	if !event is InputEventKey && !event is InputEventJoypadButton && !event is InputEventJoypadMotion:
		return #only continue if one of those
	if !event.is_pressed():
		return
	NewEvent = event
	emit_signal("NewControl")
	set_process_input(false)
	visible = false


#Localization
func retranslate()->void:
	find_node("Message").text = tr("USE_NEW_CONTROLS")
