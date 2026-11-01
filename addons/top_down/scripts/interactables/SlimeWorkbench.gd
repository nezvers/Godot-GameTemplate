## Upgrades the selected weapon for the rest of the run.
## Levels and their item costs come from weapons.<id>.upgrades in balance.json.
## Stays hidden until the player has picked up a slime ball this run.
class_name SlimeWorkbench
extends Interactable

@export var slime_resource:ScoreResource
@export var weapon_inventory:ItemCollectionResource
@export var weapon_upgrade_resource:WeaponUpgradeResource
## Frame 0 idle, frame 1 bubbling.
@export var sprite:Sprite2D

func _ready()->void:
	super()
	slime_resource.updated.connect(_update_available)
	tree_exiting.connect(slime_resource.updated.disconnect.bind(_update_available), CONNECT_ONE_SHOT)
	_update_available()

## Disabled nodes drop out of physics too, so the hidden bench doesn't block.
func _update_available()->void:
	var _available:bool = slime_resource.collected_total > 0
	visible = _available
	process_mode = Node.PROCESS_MODE_INHERIT if _available else Node.PROCESS_MODE_DISABLED

func _selected_item()->ItemResource:
	if weapon_inventory.list.is_empty():
		return null
	return weapon_inventory.list[clampi(weapon_inventory.selected, 0, weapon_inventory.list.size() - 1)]

func _next_cost(item:ItemResource)->Array:
	return weapon_upgrade_resource.next_upgrade(item.scene_path).get("cost", [])

func _can_use()->bool:
	var _item:ItemResource = _selected_item()
	if _item == null || !weapon_upgrade_resource.can_upgrade(_item.scene_path):
		return false
	return LootItems.can_afford(_next_cost(_item))

func _use()->void:
	var _item:ItemResource = _selected_item()
	LootItems.pay(_next_cost(_item))
	weapon_upgrade_resource.upgrade(_item.scene_path)
	var _tween:Tween = create_tween()
	for _frame:int in [1, 0, 1, 0]:
		_tween.tween_callback(sprite.set_frame.bind(_frame))
		_tween.tween_interval(0.12)

func _prompt_text()->String:
	var _item:ItemResource = _selected_item()
	if _item == null:
		return "No weapon"
	if !weapon_upgrade_resource.can_upgrade(_item.scene_path):
		return "%s maxed" % _item.resource_name
	var _level:int = weapon_upgrade_resource.get_level(_item.scene_path)
	return "%s Lv%d: %s" % [_item.resource_name, _level + 1, LootItems.describe(_next_cost(_item))]
