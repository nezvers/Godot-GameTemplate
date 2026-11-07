class_name TransitionManager
extends CanvasLayer

@export var texture_rect:TextureRect
@export var transition_time:float = 1.0
@export var bool_resource:BoolResource
@export var transition_material:ShaderMaterial

## Resize screen texture to create same pixelation as the game
const GAME_RESOLUTION_PIXELATION:bool = false

var tween:Tween

## Load scenes straight away, without the screen grab and fade: for windowless
## runs that really change scenes (a dedicated server, the co-op tests). Opt-in,
## so other headless tests that wander into a door don't swap their own scene.
## Also set by the user argument `--instant-transitions`.
var instant:bool = OS.get_cmdline_user_args().has("--instant-transitions")

func _ready()->void:
	visible = false

func change_scene(path:String)->void:
	bool_resource.set_value(true)
	if instant:
		ThreadUtility.load_resource(path, _instant_loaded)
		return
	# wait for rendering everything on a screen
	RenderingServer.frame_post_draw.connect(_post_draw.bind(path), CONNECT_ONE_SHOT)

func _post_draw(path:String)->void:
	var _game_resolution:Vector2i = get_viewport().content_scale_size
	var _viewport_size:Vector2i = get_viewport().size
	var _multiply:float = _game_resolution.y / float(_viewport_size.y)
	
	# get texture from the screen
	var _image:Image = get_viewport().get_texture().get_image()
	
	if GAME_RESOLUTION_PIXELATION:
		_image.resize(int(ceil(_viewport_size.x * _multiply)), _game_resolution.y, Image.INTERPOLATE_NEAREST)
		transition_material.set_shader_parameter("scale", 1.0)
	else:
		var _scale:float = float(_viewport_size.y) / _game_resolution.y
		transition_material.set_shader_parameter("scale", _scale)
	
	var _image_texture:ImageTexture = ImageTexture.create_from_image(_image)
	texture_rect.texture = _image_texture
	
	get_tree().current_scene.visible = false
	visible = true
	transition_progress(0.0)
	
	# TODO: scenes are preloaded using PreloadResource, but in case needed scene is not, load with thread
	ThreadUtility.load_resource(path, scene_loaded)

func _instant_loaded(scene:PackedScene)->void:
	assert(scene != null)
	get_tree().change_scene_to_packed(scene)
	_instant_finished.call_deferred()

func _instant_finished()->void:
	await get_tree().process_frame
	bool_resource.set_value(false)

## Set transition in motion
func scene_loaded(scene:PackedScene)->void:
	assert(scene != null)
	get_tree().change_scene_to_packed(scene)
	
	if tween != null:
		tween.kill()
	tween = create_tween()
	# small delay to remove weird stutter
	tween.tween_method(transition_progress, 0.0, 1.0, transition_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_delay(0.1)
	tween.finished.connect(transition_finished)

func transition_progress(t:float)->void:
	(texture_rect.material as ShaderMaterial).set_shader_parameter("progress", t)

func transition_finished()->void:
	visible = false
	bool_resource.set_value(false)
