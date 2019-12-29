extends CanvasLayer

func _ready()->void:
	if !Settings.HTML5:
		queue_free()
		return
	$Panel.show()
	$Button.show()

func _on_Button_pressed()->void:
	queue_free()
