## Spends slime balls to upgrade the selected weapon for the rest of the run.
## Stays hidden until the player has picked up a slime ball this run.
class_name SlimeWorkbench
extends Interactable

@export var slime_resource:ScoreResource
@export var slime_cost:int = 2
@export var weapon_inventory:ItemCollectionResource
@export var weapon_upgrade_resource:WeaponUpgradeResource
## Frame 0 idle, frame 1 bubbling.
@export var sprite:Sprite2D

@export_group("Upgrade tuning")
## Written to weapon_upgrade_resource, so balance.json can tune it here.
@export var max_level:int = 3
@export var damage_per_level:float = 0.2
@export var interval_per_level:float = 0.1

func _ready()->void:
	super()
	weapon_upgrade_resource.max_level = max_level
	weapon_upgrade_resource.damage_per_level = damage_per_level
	weapon_upgrade_resource.interval_per_level = interval_per_level
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

func _can_use()->bool:
	var _item:ItemResource = _selected_item()
	if _item == null:
		return false
	return slime_resource.can_spend(slime_cost) && weapon_upgrade_resource.can_upgrade(_item.scene_path)

func _use()->void:
	var _item:ItemResource = _selected_item()
	slime_resource.spend(slime_cost)
	weapon_upgrade_resource.upgrade(_item.scene_path)
	var _tween:Tween = create_tween()
	for _frame:int in [1, 0, 1, 0]:
		_tween.tween_callback(sprite.set_frame.bind(_frame))
		_tween.tween_interval(0.12)

func _prompt_text()->String:
	var _item:ItemResource = _selected_item()
	if _item == null:
		return "No weapon"
	var _level:int = weapon_upgrade_resource.get_level(_item.scene_path)
	if _level >= weapon_upgrade_resource.max_level:
		return "%s maxed" % _item.resource_name
	return "Upgrade %s Lv%d slime %d/%d" % [_item.resource_name, _level + 1, slime_resource.value, slime_cost]
