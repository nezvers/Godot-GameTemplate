## Saved state of the home base (room_H00): the piston memory grid, its lane
## selects, weapons lying around and the weapons coming home or going out.
## Weapons are stored by WeaponItemResource name (they are sub resources of
## weapon_database.tres, so they have no path of their own).
class_name HomeBaseResource
extends SaveableResource

signal updated

## Side of the piston grid the saved arrays belong to; a different size starts over.
@export var grid_size:int
## Row-major, 1 = raised.
@export var pistons:PackedByteArray
@export var row_select:PackedByteArray
@export var col_select:PackedByteArray
## Value Write puts into the selected cells: true raises.
@export var data_value:bool = true
## PistonGrid.Gate combining row and column selects
@export var gate:int
## Weapons lying in the home base: [{"item": name, "pos": Vector2}]
@export var dropped:Array[Dictionary]
## Weapons carried home after a victory or extract; the player holds them on arrival.
@export var stash_inventory:PackedStringArray
## The one weapon carried out to the mission, handed over by FreshStart.
@export var loadout:String

func reset_resource()->void:
	grid_size = 0
	pistons = PackedByteArray()
	row_select = PackedByteArray()
	col_select = PackedByteArray()
	data_value = true
	gate = 0
	dropped = []
	stash_inventory = PackedStringArray()
	loadout = ""
	updated.emit()

func prepare_save()->Resource:
	var _data:HomeBaseResource = HomeBaseResource.new()
	_data.grid_size = grid_size
	_data.pistons = pistons
	_data.row_select = row_select
	_data.col_select = col_select
	_data.data_value = data_value
	_data.gate = gate
	_data.dropped = dropped.duplicate(true)
	_data.stash_inventory = stash_inventory
	_data.loadout = loadout
	return _data

func prepare_load(data:Resource)->void:
	grid_size = data.grid_size
	pistons = data.pistons
	row_select = data.row_select
	col_select = data.col_select
	data_value = data.data_value
	gate = data.gate
	dropped = data.dropped.duplicate(true)
	stash_inventory = data.stash_inventory
	loadout = data.loadout
	updated.emit()

## Weapons of the finished run join the stash (victory / extract only).
func stash_weapons(inventory:ItemCollectionResource)->void:
	for _item:ItemResource in inventory.list:
		if _item != null:
			stash_inventory.append(_item.resource_name)
	save_resource()

## WeaponItemResource called `item_name` in the database, or null.
static func find_item(database:ItemCollectionResource, item_name:String)->ItemResource:
	for _item:ItemResource in database.list:
		if _item != null && _item.resource_name == item_name:
			return _item
	return null
