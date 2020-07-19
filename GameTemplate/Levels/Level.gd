extends Node2D

export (String, FILE, "*.tscn") var Next_Scene: String

func _ready()->void:
	Hud.visible = true

func _on_Button_pressed()->void:
	Game.emit_signal("ChangeScene", Next_Scene)
