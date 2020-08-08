extends CanvasLayer

enum {IDLE, IN, OUT}

var percent:float = 0 setget set_percent

func set_percent(value:float)->void:
	percent = clamp(value, 0.0, 1.0)
	#Fade logic
	$ColorRect.modulate.a = percent

func _ready()->void:
	$ColorRect.modulate.a = percent
