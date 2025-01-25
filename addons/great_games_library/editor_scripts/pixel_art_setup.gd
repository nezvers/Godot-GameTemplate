@tool extends EditorScript

## File/Run
## Ctrl + Shift + X
func _run()->void:
	ProjectSettings.set("display/window/size/viewport_width", 480)
	ProjectSettings.set("display/window/size/viewport_height", 270)
	ProjectSettings.set("display/window/size/window_width_override", 1280)
	ProjectSettings.set("display/window/size/window_height_override", 720)
	ProjectSettings.set("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set("rendering/textures/canvas_textures/default_texture_filter", "Nearest")
	ProjectSettings.save()
