## Who wears what: the host (slot 0, or the single player) keeps the plumber,
## every co-op guest is an electrician. Same 16x16, 8-frame strip layout, so only
## the texture changes. On a dedicated server slot 0 is the hidden player, so
## everyone visible is an electrician.
class_name PlayerSkin
extends RefCounted

const HOST_TEXTURE:Texture2D = preload("res://addons/top_down/assets/images/characters/plumber_16x16_strip8.png")
const GUEST_TEXTURE:Texture2D = preload("res://addons/top_down/assets/images/characters/electrician_16x16_strip8.png")
const SPRITE_PATH:NodePath = ^"Body/Stretch/Sprite2D"

static func texture_for(slot:int)->Texture2D:
	return HOST_TEXTURE if slot == 0 else GUEST_TEXTURE

## Dresses a player body (local or puppet) for its slot.
static func apply(body:Node, slot:int)->void:
	if body == null || !is_instance_valid(body):
		return
	var _sprite:Sprite2D = body.get_node_or_null(SPRITE_PATH) as Sprite2D
	if _sprite != null:
		_sprite.texture = texture_for(slot)

## A sprite on an effect copied from the local player (the corpse).
static func apply_to_sprites(node:Node, slot:int)->void:
	var _texture:Texture2D = texture_for(slot)
	for _child:Node in node.find_children("*", "Sprite2D", true, false):
		if (_child as Sprite2D).texture == HOST_TEXTURE:
			(_child as Sprite2D).texture = _texture
	if node is Sprite2D && (node as Sprite2D).texture == HOST_TEXTURE:
		(node as Sprite2D).texture = _texture
