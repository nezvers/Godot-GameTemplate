## Loot item ids shared by balance.json drops, costs and payouts.
##   Costs are lists of {"item": id, "amount": n}, paid from the item's counter.
##   Drops spawn the item's pickup at a position.
class_name LootItems

const COUNTERS:Dictionary = {
	"coin": "res://addons/top_down/resources/global_resources/score_resource.tres",
	"meat": "res://addons/top_down/resources/global_resources/meat_resource.tres",
	"slime": "res://addons/top_down/resources/global_resources/slime_resource.tres",
	"boss_crystal": "res://addons/top_down/resources/global_resources/boss_crystal_resource.tres",
}

const PICKUPS:Dictionary = {
	"coin": "res://addons/top_down/resources/InstanceResources/pickups/coin_instance_resource.tres",
	"meat": "res://addons/top_down/resources/InstanceResources/pickups/meat_instance_resource.tres",
	"slime": "res://addons/top_down/resources/InstanceResources/pickups/slime_instance_resource.tres",
	"boss_crystal": "res://addons/top_down/resources/InstanceResources/pickups/boss_crystal_instance_resource.tres",
	"health": "res://addons/top_down/resources/InstanceResources/pickups/health_pickup_instance_resource.tres",
}

## Short labels for prompts.
const LABELS:Dictionary = {
	"coin": "G",
	"meat": "meat",
	"slime": "slime",
	"boss_crystal": "crystal",
}

static func counter(id:String)->ScoreResource:
	if !COUNTERS.has(id):
		push_warning("loot: unknown item '%s'" % id)
		return null
	return load(COUNTERS[id])

static func can_afford(cost:Array)->bool:
	for _entry:Dictionary in cost:
		var _counter:ScoreResource = counter(_entry.get("item", ""))
		if _counter == null || !_counter.can_spend(int(_entry.get("amount", 1))):
			return false
	return true

## Spends every entry, or nothing when any of them is short.
static func pay(cost:Array)->bool:
	if !can_afford(cost):
		return false
	for _entry:Dictionary in cost:
		counter(_entry.item).spend(int(_entry.get("amount", 1)))
	return true

## "1/2 slime + 0/3 meat": what the player has against what it costs.
static func describe(cost:Array)->String:
	var _parts:PackedStringArray = []
	for _entry:Dictionary in cost:
		var _id:String = _entry.get("item", "")
		var _counter:ScoreResource = counter(_id)
		var _have:int = _counter.value if _counter != null else 0
		_parts.append("%d/%d %s" % [_have, int(_entry.get("amount", 1)), LABELS.get(_id, _id)])
	return " + ".join(_parts)

static func can_spawn(id:String)->bool:
	return PICKUPS.has(id)

static func spawn(id:String, amount:int, position:Vector2)->void:
	if amount <= 0:
		return
	if !PICKUPS.has(id):
		push_warning("loot: no pickup for '%s'" % id)
		return
	var _instance_resource:InstanceResource = load(PICKUPS[id])
	for i:int in amount:
		_instance_resource.instance(func (inst:Node2D)->void: inst.global_position = position)

## A chance above 1 is guaranteed drops plus a roll for one more: 1.5 = 1, 50% for 2.
static func roll_count(chance:float, value:float)->int:
	if chance <= 0.0:
		return 0
	var _whole:int = floori(chance)
	return _whole + (1 if value < chance - _whole else 0)
