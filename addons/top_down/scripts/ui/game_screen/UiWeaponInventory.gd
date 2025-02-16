class_name UiWeaponInventory
extends HBoxContainer

@export var prefab_slot_node:Control

@export var prefab_icon_nodepath:NodePath = "Icon"

@export var inventory_resource:ItemCollectionResource

@export var selected_texture:Texture2D

@export var slot_texture:Texture2D

var slot_scene:PackedScene

var slot_list:Array[TextureRect]
var icon_list:Array[TextureRect]

func _ready()->void:
	slot_scene = ScenePacker.create_package(prefab_slot_node, true)
	for _child:Node in get_children():
		remove_child(_child)
		_child.queue_free()
	
	slot_list.clear()
	icon_list.clear()
	for i:int in inventory_resource.max_items:
		var _slot:TextureRect = slot_scene.instantiate()
		_slot.name = "Slot%d" % i
		add_child(_slot)
		slot_list.append(_slot)
		icon_list.append(_slot.get_node(prefab_icon_nodepath))
	
	inventory_resource.updated.connect(_on_update)
	_on_update()
	
	inventory_resource.selected_changed.connect(_on_selected_changed)
	_on_selected_changed()

func _on_update()->void:
	for i:int in inventory_resource.max_items:
		if i < inventory_resource.list.size():
			icon_list[i].texture = inventory_resource.list[i].icon
		else:
			icon_list[i].texture = null

func _on_selected_changed()->void:
	for i:int in slot_list.size():
		if i == inventory_resource.selected:
			slot_list[i].texture = selected_texture
		else:
			slot_list[i].texture = slot_texture
