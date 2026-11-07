## Co-op world sync: enemies, loot, shots and arena fights. Lives under the Net
## autoload as /root/Net/Entities, so its RPC path is the same on every peer.
##
## The host owns the world:
## - Enemies and loot spawned on the host (any InstanceResource under actors/ or
##   pickups/, see InstanceResource.instanced_hook) get a net id and are created
##   on the guests in the same room. Guest copies are puppets: their AI is off,
##   snapshots (20 Hz) move them, and they leave when the host's one does.
## - Arena sections run only on the host; guests mirror their state.
## - A guest's hit on an enemy copy is measured on the guest (it saw it land)
##   and applied on the host (_hit). Enemy hits on a teammate's copy on the host
##   are sent to that teammate, who applies them to itself (send_hurt / _hurt).
## - Loot is collected locally by whoever touches it first; a guest tells the
##   host, which removes it for everyone.
## Shots are fire-and-forget: every projectile spawned on this machine (not a
## replay) is replayed on the others as a harmless copy, so everyone sees every
## shot. Traps and puddles come from those copies on each machine and only
## affect that machine's own player.
class_name NetEntities
extends Node

enum Kind {ENEMY, PICKUP, SHOT, EFFECT}

const SNAPSHOT_INTERVAL:float = 0.05
const IR:String = "res://addons/top_down/resources/InstanceResources/"
const FOLDERS:Dictionary = {"actors/": Kind.ENEMY, "pickups/": Kind.PICKUP, "projectiles/": Kind.SHOT}
## Each machine handles these on its own.
const LOCAL_ONLY:PackedStringArray = [IR + "actors/player_instance_resource.tres", IR + "pickups/item_pickup_instance_resource.tres"]
const EFFECTS:PackedStringArray = [IR + "vfx/enemy_spawn_mark.tres", IR + "vfx/spawn_dust_instance.tres"]
## Children of an enemy kept running on a puppet; everything else (AI, attacks,
## movement, splitting, drops) is switched off.
const PUPPET_KEEP:PackedStringArray = [
	"ResourceNode", "CollisionShape2D", "AreaReceiver2D", "Shadow", "Body", "CharacterStates",
	"SpriteFlip", "ActorDamage", "DamageDisplay", "DamageSetup", "StatusSetup", "PoolNode",
	"DamageCooldown", "BalanceBinding", "DifficultyHealth", "SlowEffect", "SlipperyEffect",
	"EmpoweredEffect", "AcidEffect", "PoisonEffect", "NetPuppet",
]
const MAX_DAMAGE:float = 100000.0
const MAX_PATH:int = 200

## resource path -> Kind, built once from the InstanceResources folders.
var catalogue:Dictionary = {}
## net id -> node, for enemies and loot (host: the real ones, guest: copies).
var entities:Dictionary = {}
## net id -> Kind
var kinds:Dictionary = {}
## net id -> InstanceResource path
var _paths:Dictionary = {}
## Host: node instance id -> net id
var _ids:Dictionary = {}
var _next_id:int = 1
## Host: peer id -> room it has been sent the full state of.
var _synced:Dictionary = {}
## Guest: ids being removed on the host's word (not collected here).
var _removing:Dictionary = {}
var _snapshot_left:float
var _scene:Node
## Spawning a replay: the hook must not send it back out.
var _replaying:bool

func _ready()->void:
	_build_catalogue()
	InstanceResource.instanced_hook = _on_instanced

func net()->Node:
	return get_parent()

func _build_catalogue()->void:
	for _folder:String in FOLDERS:
		for _file:String in _list(IR + _folder):
			var _path:String = IR + _folder + _file
			if !LOCAL_ONLY.has(_path):
				catalogue[_path] = FOLDERS[_folder]
	for _path:String in EFFECTS:
		catalogue[_path] = Kind.EFFECT

static func _list(folder:String)->PackedStringArray:
	var _files:PackedStringArray = []
	for _file:String in DirAccess.get_files_at(folder):
		# exported builds list remapped resources
		_file = _file.trim_suffix(".remap")
		if _file.ends_with(".tres") && !_files.has(_file):
			_files.append(_file)
	return _files

func current_room()->String:
	var _now:Node = get_tree().current_scene
	return _now.scene_file_path if _now != null else ""

## Guests standing in the host's current room.
func _guests_here()->Array[PlayerState]:
	var _list:Array[PlayerState] = []
	var _room:String = current_room()
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && _state.room_scene == _room && !_room.is_empty():
			_list.append(_state)
	return _list

func _physics_process(delta:float)->void:
	if !net().is_online():
		if !entities.is_empty() || !_synced.is_empty():
			_reset()
		return
	var _now:Node = get_tree().current_scene
	if _now != _scene:
		_scene = _now
		_on_room_changed()
	if !net().is_host():
		return
	for _state:PlayerState in _guests_here():
		if _synced.get(_state.peer_id, "") != current_room():
			_full_sync(_state.peer_id)
	_snapshot_left -= delta
	if _snapshot_left <= 0.0:
		_snapshot_left = SNAPSHOT_INTERVAL
		_send_snapshot()

func _reset()->void:
	for _id:int in entities.keys():
		if net().is_guest() || !net().is_online():
			_drop_copy(_id)
	entities.clear()
	kinds.clear()
	_ids.clear()
	_synced.clear()
	_removing.clear()
	_paths.clear()

func _on_room_changed()->void:
	# entities belonged to the room that's gone (puppets went with it)
	entities.clear()
	kinds.clear()
	_ids.clear()
	_removing.clear()
	_synced.clear()
	_paths.clear()
	if net().is_host() && _scene != null:
		_watch_sections.call_deferred(_scene)

# --- Host: spawns ------------------------------------------------------------------

func _on_instanced(resource:InstanceResource, node:Node)->void:
	if _replaying || !net().is_online():
		return
	var _kind:Variant = catalogue.get(resource.resource_path)
	if _kind == null:
		return
	if _kind == Kind.SHOT:
		_send_shot(resource.resource_path, node)
		return
	if !net().is_host() || !(node is Node2D):
		return
	if _kind == Kind.EFFECT:
		for _state:PlayerState in _guests_here():
			_effect.rpc_id(_state.peer_id, current_room(), resource.resource_path, (node as Node2D).global_position)
		return
	var _id:int = _next_id
	_next_id += 1
	entities[_id] = node
	kinds[_id] = _kind
	_paths[_id] = resource.resource_path
	_ids[node.get_instance_id()] = _id
	node.tree_exiting.connect(_on_host_entity_exiting.bind(_id, node), CONNECT_ONE_SHOT)
	for _state:PlayerState in _guests_here():
		if _synced.get(_state.peer_id, "") == current_room():
			_spawn.rpc_id(_state.peer_id, current_room(), _id, resource.resource_path, (node as Node2D).global_position)

func _on_host_entity_exiting(id:int, node:Node)->void:
	if entities.get(id) != node:
		return
	entities.erase(id)
	kinds.erase(id)
	_paths.erase(id)
	_ids.erase(node.get_instance_id())
	if !net().is_host():
		return
	var _died:bool = false
	var _resources:ResourceNode = node.get_node_or_null("ResourceNode")
	var _health:HealthResource = _resources.get_resource("health") if _resources != null else null
	if _health != null:
		_died = _health.is_dead
	for _state:PlayerState in _guests_here():
		_despawn.rpc_id(_state.peer_id, id, _died)

## A guest just arrived in our room: everything alive and every fight.
func _full_sync(peer:int)->void:
	_synced[peer] = current_room()
	for _id:int in entities:
		var _node:Node2D = entities[_id]
		if is_instance_valid(_node) && _node.is_inside_tree():
			_spawn.rpc_id(peer, current_room(), _id, _resource_path_of(_id), _node.global_position)
	for _section:ArenaSection in _sections(get_tree().current_scene):
		_send_section(_section, peer)

func _resource_path_of(id:int)->String:
	return _paths.get(id, "")

func _send_snapshot()->void:
	var _guests:Array[PlayerState] = _guests_here()
	if _guests.is_empty():
		return
	var _list:PackedInt32Array = []
	var _positions:PackedVector2Array = []
	var _hp:PackedByteArray = []
	for _id:int in entities:
		if kinds[_id] != Kind.ENEMY:
			continue
		var _node:Node2D = entities[_id]
		if !is_instance_valid(_node) || !_node.is_inside_tree():
			continue
		_list.append(_id)
		_positions.append(_node.global_position)
		var _health:HealthResource = (_node.get_node("ResourceNode") as ResourceNode).get_resource("health")
		_hp.append(clampi(roundi(255.0 * _health.hp / maxf(_health.max_hp, 1.0)), 0, 255) if _health != null else 255)
	if _list.is_empty():
		return
	for _state:PlayerState in _guests:
		if _synced.get(_state.peer_id, "") == current_room():
			_snapshot.rpc_id(_state.peer_id, _list, _positions, _hp)

# --- Host: fights ---------------------------------------------------------------

func _watch_sections(room:Node)->void:
	if !is_instance_valid(room):
		return
	for _section:ArenaSection in _sections(room):
		var _send:Callable = _on_section_changed.bind(_section)
		for _signal:Signal in [_section.fight_started, _section.cleared, _section.updated]:
			if !_signal.is_connected(_send):
				_signal.connect(_send)

func _on_section_changed(section:ArenaSection)->void:
	if !net().is_host() || !is_instance_valid(section):
		return
	for _state:PlayerState in _guests_here():
		if _synced.get(_state.peer_id, "") == current_room():
			_send_section(section, _state.peer_id)

func _send_section(section:ArenaSection, peer:int)->void:
	var _room:Node = get_tree().current_scene
	if _room == null || !_room.is_ancestor_of(section):
		return
	_section_state.rpc_id(peer, current_room(), str(_room.get_path_to(section)), section.fight_active, section.is_cleared, section.wave_index, section.enemy_count)

static func _sections(node:Node)->Array[ArenaSection]:
	var _list:Array[ArenaSection] = []
	if node == null:
		return _list
	if node is ArenaSection:
		_list.append(node)
	for _child:Node in node.get_children():
		_list.append_array(_sections(_child))
	return _list

# --- Guest: applying the host's world -----------------------------------------------

func _from_host()->bool:
	return net().is_guest() && multiplayer.get_remote_sender_id() == 1

@rpc("authority", "call_remote", "reliable")
func _spawn(room:String, id:int, path:String, at:Vector2)->void:
	if !_from_host() || room != current_room() || entities.has(id) || !at.is_finite():
		return
	var _kind:Variant = catalogue.get(path)
	if _kind != Kind.ENEMY && _kind != Kind.PICKUP:
		return
	var _resource:InstanceResource = load(path)
	if _resource.parent_reference_resource == null || _resource.parent_reference_resource.node == null:
		return
	_replaying = true
	var _node:Node = _resource.instance(func (inst:Node)->void:
		(inst as Node2D).global_position = at
		if _kind == Kind.ENEMY:
			_make_puppet(inst))
	_replaying = false
	entities[id] = _node
	kinds[id] = _kind
	_paths[id] = path
	_node.tree_exiting.connect(_on_copy_exiting.bind(id, _node, _resource), CONNECT_ONE_SHOT)

## AI, attacks and movement off; the snapshots move it, the host decides its hp.
func _make_puppet(enemy:Node)->void:
	for _child:Node in enemy.get_children():
		if !PUPPET_KEEP.has(_child.name):
			_child.process_mode = Node.PROCESS_MODE_DISABLED
			_child.set_meta(&"net_disabled", true)
	if !enemy.has_node("NetPuppet"):
		var _driver:NetPuppet = NetPuppet.new()
		_driver.name = "NetPuppet"
		enemy.add_child(_driver)
	(enemy.get_node("NetPuppet") as NetPuppet).reset((enemy as Node2D).global_position)
	ActiveEnemy.insert_child(enemy, null)
	enemy.ready.connect(_hook_puppet_damage.bind(enemy), CONNECT_ONE_SHOT)

func _hook_puppet_damage(enemy:Node)->void:
	var _damage:DamageResource = (enemy.get_node("ResourceNode") as ResourceNode).get_resource("damage")
	if _damage != null:
		_damage.forward_hit = _on_puppet_hit.bind(enemy)

func _on_puppet_hit(data:DamageDataResource, enemy:Node)->void:
	for _id:int in entities:
		if entities[_id] == enemy:
			_hit.rpc_id(1, _id, data.total_damage, data.direction * data.kickback_strength, data.is_critical)
			return

## A copy left our tree: picked up here (tell the host) or removed on its word.
## Copies never go back to the pool: they'd come out as puppets in a solo game.
func _on_copy_exiting(id:int, node:Node, resource:InstanceResource)->void:
	var _collected:bool = !_removing.has(id) && kinds.get(id) == Kind.PICKUP && entities.get(id) == node
	_removing.erase(id)
	if entities.get(id) == node:
		entities.erase(id)
		kinds.erase(id)
		_paths.erase(id)
	if _collected && net().is_guest():
		_collected_here.rpc_id(1, id)
	_unpool.call_deferred(node, resource)

func _unpool(node:Node, resource:InstanceResource)->void:
	await get_tree().process_frame
	resource.pool_list.erase(node)
	if is_instance_valid(node) && !node.is_inside_tree():
		node.queue_free()

@rpc("authority", "call_remote", "reliable")
func _despawn(id:int, died:bool)->void:
	if !_from_host() || !entities.has(id):
		return
	var _node:Node2D = entities[id]
	if died && is_instance_valid(_node):
		_play_death(_node)
	_drop_copy(id)

func _drop_copy(id:int)->void:
	var _node:Node = entities.get(id)
	_removing[id] = true
	if _node == null || !is_instance_valid(_node):
		entities.erase(id)
		return
	if _node.is_inside_tree():
		_node.get_parent().remove_child(_node)
	else:
		_node.queue_free()

## The death look of ActorDamage, without its side effects (drops, splits).
func _play_death(node:Node2D)->void:
	var _damage:Node = node.get_node_or_null("ActorDamage")
	if _damage == null:
		return
	var _vfx:Variant = _damage.get("dead_vfx_instance_resource")
	if _vfx is InstanceResource:
		var _at:Vector2 = node.global_position
		(_vfx as InstanceResource).instance(func (inst:Node)->void:
			if inst is Node2D:
				(inst as Node2D).global_position = _at)
	var _sound:Variant = _damage.get("sound_resource_dead")
	if _sound != null && _sound.has_method("play_managed"):
		_sound.play_managed()

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _snapshot(list:PackedInt32Array, positions:PackedVector2Array, hp:PackedByteArray)->void:
	if !_from_host() || list.size() != positions.size() || list.size() != hp.size():
		return
	for _i:int in list.size():
		var _node:Node = entities.get(list[_i])
		if _node == null || !is_instance_valid(_node) || !positions[_i].is_finite():
			continue
		var _driver:NetPuppet = _node.get_node_or_null("NetPuppet")
		if _driver != null:
			_driver.push(positions[_i], hp[_i] / 255.0)

@rpc("authority", "call_remote", "reliable")
func _section_state(room:String, path:String, active:bool, cleared:bool, index:int, count:int)->void:
	if !_from_host() || room != current_room() || path.length() > MAX_PATH:
		return
	var _section:ArenaSection = get_tree().current_scene.get_node_or_null(NodePath(path)) as ArenaSection
	if _section != null:
		_section.apply_net_state(active, cleared, index, count)

@rpc("authority", "call_remote", "unreliable")
func _effect(room:String, path:String, at:Vector2)->void:
	if !_from_host() || room != current_room() || catalogue.get(path) != Kind.EFFECT || !at.is_finite():
		return
	var _resource:InstanceResource = load(path)
	if _resource.parent_reference_resource == null || _resource.parent_reference_resource.node == null:
		return
	_replaying = true
	_resource.instance(func (inst:Node)->void: (inst as Node2D).global_position = at)
	_replaying = false

## The host hit our player's copy there: take the hit here.
@rpc("authority", "call_remote", "reliable")
func _hurt(amount:float, impulse:Vector2, critical:bool)->void:
	if !_from_host() || !is_finite(amount) || amount < 0.0 || amount > MAX_DAMAGE || !impulse.is_finite():
		return
	var _body:Node2D = net().players.local_body()
	if _body != null:
		apply_hit(_body, amount, impulse, critical)

# --- Host: requests from guests -------------------------------------------------------

func _sender_state()->PlayerState:
	var _peer:int = multiplayer.get_remote_sender_id()
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && _state.peer_id == _peer:
			return _state
	return null

## A guest's shot landed on its copy of enemy `id`.
@rpc("any_peer", "call_remote", "reliable")
func _hit(id:int, amount:float, impulse:Vector2, critical:bool)->void:
	if !net().is_host() || _sender_state() == null || kinds.get(id) != Kind.ENEMY:
		return
	if !is_finite(amount) || amount < 0.0 || amount > MAX_DAMAGE || !impulse.is_finite() || impulse.length() > 10000.0:
		return
	var _node:Node = entities[id]
	if is_instance_valid(_node) && _node.is_inside_tree():
		apply_hit(_node, amount, impulse, critical)

## A guest picked up loot `id`: gone for everyone.
@rpc("any_peer", "call_remote", "reliable")
func _collected_here(id:int)->void:
	if !net().is_host() || _sender_state() == null || kinds.get(id) != Kind.PICKUP:
		return
	var _node:Node = entities[id]
	if !is_instance_valid(_node) || !_node.is_inside_tree():
		return
	var _pool:PoolNode = _node.get_node_or_null("PoolNode")
	if _pool != null:
		_pool.pool_return()
	else:
		_node.queue_free()

## Host, from a teammate's copy (RemotePlayer): that teammate takes the hit.
func send_hurt(state:PlayerState, data:DamageDataResource)->void:
	if state == null || state.is_local:
		return
	_hurt.rpc_id(state.peer_id, data.total_damage, data.direction * data.kickback_strength, data.is_critical)

## The end of DamageDataResource.process for damage measured elsewhere: push,
## hp, and the received/kill signals that drive flashes, splits and deaths.
static func apply_hit(actor:Node, amount:float, impulse:Vector2, critical:bool)->void:
	var _resources:ResourceNode = actor.get_node_or_null("ResourceNode")
	if _resources == null:
		return
	var _damage:DamageResource = _resources.get_resource("damage")
	var _health:HealthResource = _resources.get_resource("health")
	if _damage == null || _health == null || !_damage.can_receive_damage || _health.is_dead:
		return
	var _push:PushResource = _resources.get_resource("push")
	if _push != null:
		_push.add_impulse(impulse)
	if amount <= 0.0:
		return
	var _data:DamageDataResource = DamageDataResource.new("damage")
	_data.total_damage = amount
	_data.is_critical = critical
	_data.direction = impulse.normalized()
	_health.add_hp(-amount)
	_data.is_kill = _health.is_dead
	_damage.receive(_data)

# --- Shots (every machine) ---------------------------------------------------------

func _send_shot(path:String, node:Node)->void:
	if !(node is Projectile2D):
		return
	var _shot:Projectile2D = node
	# a harmless copy (or something it spawned) isn't sent back out
	if _shot.damage_data_resource != null && _shot.damage_data_resource.has_meta(&"net_cosmetic"):
		return
	_shot_fired.rpc(current_room(), path, _shot.global_position, _shot.direction, _shot.destination)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _shot_fired(room:String, path:String, at:Vector2, direction:Vector2, destination:Vector2)->void:
	if room != current_room() || catalogue.get(path) != Kind.SHOT || !at.is_finite() || !direction.is_finite() || !destination.is_finite():
		return
	var _peer:int = multiplayer.get_remote_sender_id()
	if _peer != 1 && _sender_state() == null:
		return
	var _resource:InstanceResource = load(path)
	if _resource.parent_reference_resource == null || _resource.parent_reference_resource.node == null:
		return
	_replaying = true
	_resource.instance(func (inst:Node)->void:
		var _shot:Projectile2D = inst
		_shot.global_position = at
		_shot.direction = direction
		_shot.destination = destination
		# walls only, no damage, no push: the real shot is on the machine that fired it
		_shot.collision_mask &= 1
		var _harmless:DamageDataResource = DamageDataResource.new("damage")
		_harmless.critical_chance = 0.0
		_harmless.set_meta(&"net_cosmetic", true)
		_shot.damage_data_resource = _harmless)
	_replaying = false
