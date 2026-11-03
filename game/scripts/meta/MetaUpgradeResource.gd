## Saved meta progress: which upgrade nodes are bought with boss crystals.
## The graph itself (costs, requires, effects) comes from MetaUpgrades / upgrades.json.
class_name MetaUpgradeResource
extends SaveableResource

signal updated

enum State {LOCKED, AVAILABLE, OWNED}

## Saved: bought node ids. The root is always owned and never listed.
@export var owned:PackedStringArray = []

func is_owned(id:String)->bool:
	return id == MetaUpgrades.ROOT || owned.has(id)

## OWNED, AVAILABLE once any required node is owned, otherwise LOCKED.
func state(id:String)->State:
	if is_owned(id):
		return State.OWNED
	for _required:String in MetaUpgrades.requires(id):
		if is_owned(_required):
			return State.AVAILABLE
	return State.LOCKED

func can_buy(id:String)->bool:
	return state(id) == State.AVAILABLE && LootItems.can_afford(MetaUpgrades.cost(id))

## Pays the node's cost and owns it; false and nothing changes when it can't.
func buy(id:String)->bool:
	if !can_buy(id) || !LootItems.pay(MetaUpgrades.cost(id)):
		return false
	owned.append(id)
	save_resource()
	updated.emit()
	return true

## Gives back everything spent and keeps only the root.
func refund_all()->void:
	for _id:String in owned:
		for _entry:Dictionary in MetaUpgrades.cost(_id):
			var _counter:ScoreResource = LootItems.counter(_entry.get("item", ""))
			if _counter != null:
				_counter.refund(int(_entry.get("amount", 1)))
	owned = []
	save_resource()
	updated.emit()

## Sum of a stat over every owned node.
func stat(key:String)->float:
	var _total:float = 0.0
	for _id:String in MetaUpgrades.nodes():
		if is_owned(_id):
			_total += float(MetaUpgrades.effects(_id).get(key, 0.0))
	return _total

func reset_resource()->void:
	owned = []
	updated.emit()

func prepare_save()->Resource:
	var _data:MetaUpgradeResource = MetaUpgradeResource.new()
	_data.owned = owned.duplicate()
	return _data

func prepare_load(data:Resource)->void:
	owned = data.owned.duplicate()
	updated.emit()
