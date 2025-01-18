class_name PreloadResource
extends Resource

signal preload_finished

## TODO: move shaders and partickle list in InstanceResource
@export var instance_resource_list:Array[InstanceResource]

@export var particle_process_material_list:Array[Material]
@export var shader2d_list:Array[Shader]

## 2D Materials without shader scripts
@export var canvas_material_list:Array[Material]

@export var packed_scenes_list:Array[String]

## PackedScenes are held in memory
var cached_packed_scenes:Array[PackedScene]

var instance_resources_done:bool
var particle_process_materials_done:bool
var shaders_done:bool


func _set_instance_resources_done(value:bool)->void:
	instance_resources_done = value
	print("BootPreloader [INFO]: instance resources - DONE")
	_check_done()

func _set_particle_process_materials_done(value:bool)->void:
	particle_process_materials_done = value
	print("BootPreloader [INFO]: Shaders - DONE")
	_check_done()

func _set_shaders_done(value:bool)->void:
	shaders_done = value
	print("BootPreloader [INFO]: Shaders - DONE")
	_check_done()

func _check_done()->void:
	if !instance_resources_done:
		return
	if !particle_process_materials_done:
		return
	# TODO: add shader preload
	#if !shaders_done:
		#return
	preload_finished.emit()


func start(parent_node:Node)->void:
	
	# preload InstanceResoource scenes
	# Just in case, use the same thread for loading all scenes, to not create conflicts with shared resources
	var _scene_list:Array[Dictionary]
	for _instance_resource in instance_resource_list:
		var _data:Dictionary = {path = _instance_resource.scene_path, callback = _instance_resource.set_scene}
		_scene_list.append(_data)
	
	# Resgular Scenes loaded in same thread as InstanceResource scenes
	for _path:String in packed_scenes_list:
		var _data:Dictionary = {path = _path, callback = cached_packed_scenes.append}
		_scene_list.append(_data)
	
	ThreadUtility.load_resource_list(_scene_list, _set_instance_resources_done.bind(true))
	
	for _ppm:Material in particle_process_material_list:
		_compile_ppm(_ppm, parent_node)
	
	for _shader:Shader in shader2d_list:
		_compile_shader2d(_shader, parent_node)
	
	for _material:Material in canvas_material_list:
		_compile_material2d(_material, parent_node)
	
	# Delay one frame for ParticleProcessMaterials
	var _tree:SceneTree = parent_node.get_tree()
	if _tree != null:
		_tree.process_frame.connect(_set_particle_process_materials_done.bind(true), CONNECT_ONE_SHOT)
	# TODO: Precompile shaders

func _compile_ppm(material:Material, parent_node:Node)->void:
	var _node:GPUParticles2D = GPUParticles2D.new()
	_node.scale = Vector2.ZERO
	_node.process_material = material
	_node.amount = 1
	_node.one_shot = true
	
	var _ready_callback:Callable = func (node:GPUParticles2D)->void:
		node.emitting = true
		node.get_tree().process_frame.connect(node.queue_free, CONNECT_ONE_SHOT)
	# node will execute callback by itself
	_node.ready.connect(_ready_callback.bind(_node))
	
	# deffered to guarantee on main thread, in case this is called from thread
	parent_node.add_child.call_deferred(_node)

func _compile_shader2d(shader:Shader, parent_node:Node)->void:
	var _node:ColorRect = ColorRect.new()
	var _material:ShaderMaterial = ShaderMaterial.new()
	_material.shader = shader
	_node.material = _material
	_node.scale = Vector2.ZERO
	
	var _ready_callback:Callable = func (node:ColorRect)->void:
		node.get_tree().process_frame.connect(node.queue_free, CONNECT_ONE_SHOT)
	# node will execute callback by itself
	_node.ready.connect(_ready_callback.bind(_node))
	
	# deffered to guarantee on main thread, in case this is called from thread
	parent_node.add_child.call_deferred(_node)

func _compile_material2d(material:Material, parent_node:Node)->void:
	var _node:ColorRect = ColorRect.new()
	_node.material = material
	_node.scale = Vector2.ZERO
	
	var _ready_callback:Callable = func (node:ColorRect)->void:
		node.get_tree().process_frame.connect(node.queue_free, CONNECT_ONE_SHOT)
	# node will execute callback by itself
	_node.ready.connect(_ready_callback.bind(_node))
	
	# deffered to guarantee on main thread, in case this is called from thread
	parent_node.add_child.call_deferred(_node)
