extends Popup

signal NewControl

var NewEvent:InputEvent

func _ready()->void:
	popup_exclusive = true
	set_process_input(false)
	connect("about_to_show", self, "receive_input")
	#Localization
	SettingsLanguage.connect("ReTranslate", self, "retranslate")
	retranslate()

func receive_input()->void:
	set_process_input(true)
	get_focus_owner().release_focus()

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
	find_node("Cancel").text = tr("CANCEL")
	find_node("Message").text = tr("USE_NEW_CONTROLS")


func _on_Cancel_pressed():
	NewEvent = null
	emit_signal("NewControl")
	set_process_input(false)
	visible = false
