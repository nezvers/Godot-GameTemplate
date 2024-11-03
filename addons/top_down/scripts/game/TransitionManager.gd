class_name TransitionManager
extends CanvasLayer

@export var texture_rect:TextureRect
@export var transition_time:float = 1.0

var tween:Tween

func _ready()->void:
	visible = false

func change_scene(path:String)->void:
	# wait for rendering everything on a screen
	await RenderingServer.frame_post_draw
	
	var _game_resolution:Vector2i = get_viewport().content_scale_size
	var _viewport_size:Vector2i = get_viewport().size
	var _multiply:float = _game_resolution.y / float(_viewport_size.y)
	
	# get texture from the screen
	var _image:Image = get_viewport().get_texture().get_image()
	_image.resize(int(ceil(_viewport_size.x * _multiply)), _game_resolution.y, Image.INTERPOLATE_NEAREST)
	var _image_texture:ImageTexture = ImageTexture.create_from_image(_image)
	texture_rect.texture = _image_texture
	
	get_tree().current_scene.visible = false
	visible = true
	transition_progress(0.0)
	
	ThreadUtility.load_resource(path, scene_loaded)

## Set transition in motion
func scene_loaded(scene:PackedScene)->void:
	assert(scene != null)
	get_tree().change_scene_to_packed(scene)
	
	if tween != null:
		tween.kill()
	tween = create_tween()
	# small delay to remove weird stutter
	tween.tween_method(transition_progress, 0.0, 1.0, transition_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_delay(0.1)
	tween.finished.connect(set_visible.bind(false))

func transition_progress(t:float)->void:
	(texture_rect.material as ShaderMaterial).set_shader_parameter("progress", t)