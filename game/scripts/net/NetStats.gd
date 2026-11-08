## Link health per peer (/root/Net/Stats on every machine). The host probes each
## guest, a guest probes the host: a small numbered probe every PROBE_INTERVAL,
## answered at once. Over the last WINDOW seconds:
##   health  share of probes answered (both ways across the link), 0..1
##   rtt     mean round trip of the answered ones, ms
##   jitter  spread of those round trips (max - min), ms
## ENet's own round trip and loss figures ride along for the playtest log.
class_name NetStats
extends Node

signal updated

const PROBE_INTERVAL:float = 0.1
const WINDOW:float = 3.0
## Probes younger than this aren't counted yet: their answer may be on the way.
const GRACE:float = 0.5
const UPDATE_INTERVAL:float = 1.0
## Probes and answers travel on their own channel: a late snapshot doesn't hold them up.
const CHANNEL:int = 2

## peer id -> {"sent": {seq: time}, "rtts": [[time, rtt]], "seq": int}
var _links:Dictionary = {}
## peer id -> {"rtt_ms", "health", "jitter_ms", "enet_rtt_ms", "enet_loss"}
var _stats:Dictionary = {}
var _probe_left:float
var _update_left:float

func net()->Node:
	return get_parent()

## {"rtt_ms", "health" (0..1), "jitter_ms", "enet_rtt_ms", "enet_loss" (0..1)}, or {} when not measured.
func link(peer_id:int)->Dictionary:
	return _stats.get(peer_id, {})

func peers()->Array:
	return _stats.keys()

func _targets()->PackedInt32Array:
	var _list:PackedInt32Array = []
	if !net().is_linked() || !multiplayer.has_multiplayer_peer():
		return _list
	if net().is_host():
		for _peer:int in multiplayer.get_peers():
			_list.append(_peer)
	else:
		_list.append(1)
	return _list

func _process(delta:float)->void:
	var _targets_now:PackedInt32Array = _targets()
	if _targets_now.is_empty():
		if !_links.is_empty() || !_stats.is_empty():
			_links.clear()
			_stats.clear()
			updated.emit()
		return
	for _peer:int in _links.keys():
		if !_targets_now.has(_peer):
			_links.erase(_peer)
			_stats.erase(_peer)
	var _now:float = NetInterp.now()
	_probe_left -= delta
	if _probe_left <= 0.0:
		_probe_left = PROBE_INTERVAL
		for _peer:int in _targets_now:
			var _link:Dictionary = _links.get_or_add(_peer, {"sent": {}, "rtts": [], "seq": 0})
			_link.seq = int(_link.seq) + 1
			(_link.sent as Dictionary)[int(_link.seq)] = _now
			_probe.rpc_id(_peer, int(_link.seq))
	_update_left -= delta
	if _update_left <= 0.0:
		_update_left = UPDATE_INTERVAL
		for _peer:int in _targets_now:
			_measure(_peer, _now)
		updated.emit()

@rpc("any_peer", "call_remote", "unreliable", CHANNEL)
func _probe(seq:int)->void:
	var _from:int = multiplayer.get_remote_sender_id()
	if net().is_host() || _from == 1:
		_probe_ack.rpc_id(_from, seq)

@rpc("any_peer", "call_remote", "unreliable", CHANNEL)
func _probe_ack(seq:int)->void:
	var _link:Dictionary = _links.get(multiplayer.get_remote_sender_id(), {})
	if _link.is_empty() || !(_link.sent as Dictionary).has(seq):
		return
	var _now:float = NetInterp.now()
	var _sent_at:float = (_link.sent as Dictionary)[seq]
	(_link.sent as Dictionary).erase(seq)
	(_link.rtts as Array).append([_sent_at, _now - _sent_at])

func _measure(peer:int, now:float)->void:
	var _link:Dictionary = _links.get(peer, {})
	if _link.is_empty():
		return
	var _from:float = now - WINDOW - GRACE
	var _to:float = now - GRACE
	# forget what's older than the window
	var _sent:Dictionary = _link.sent
	for _seq:int in _sent.keys():
		if float(_sent[_seq]) < _from:
			_sent.erase(_seq)
	var _rtts:Array = (_link.rtts as Array).filter(func (e:Array)->bool: return float(e[0]) >= _from)
	_link.rtts = _rtts
	# answered in the window vs lost (still unanswered after the grace)
	var _answered:int = 0
	var _sum:float = 0.0
	var _low:float = INF
	var _high:float = 0.0
	for _entry:Array in _rtts:
		if float(_entry[0]) > _to:
			continue
		_answered += 1
		_sum += float(_entry[1])
		_low = minf(_low, float(_entry[1]))
		_high = maxf(_high, float(_entry[1]))
	var _lost:int = 0
	for _seq:int in _sent:
		if float(_sent[_seq]) <= _to:
			_lost += 1
	var _total:int = _answered + _lost
	if _total == 0:
		return
	var _result:Dictionary = {
		"health": float(_answered) / float(_total),
		"rtt_ms": (_sum / _answered * 1000.0) if _answered > 0 else -1.0,
		"jitter_ms": ((_high - _low) * 1000.0) if _answered > 0 else 0.0,
	}
	var _enet:ENetPacketPeer = _enet_peer(peer)
	if _enet != null:
		_result["enet_rtt_ms"] = _enet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		_result["enet_loss"] = _enet.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE)
	_stats[peer] = _result

func _enet_peer(peer:int)->ENetPacketPeer:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer)
	return null

## "42ms 98%" for the HUD, "" when not measured yet.
static func describe(stats:Dictionary)->String:
	if stats.is_empty():
		return ""
	var _rtt:float = float(stats.get("rtt_ms", -1.0))
	var _rtt_text:String = "--ms" if _rtt < 0.0 else "%dms" % roundi(_rtt)
	return "%s %d%%" % [_rtt_text, roundi(float(stats.get("health", 0.0)) * 100.0)]

const GOOD_COLOR:Color = Color("62c370")
const FAIR_COLOR:Color = Color("f2c14e")
const BAD_COLOR:Color = Color("e5534b")

static func health_color(stats:Dictionary)->Color:
	var _health:float = float(stats.get("health", 0.0))
	if _health >= 0.95:
		return GOOD_COLOR
	if _health >= 0.8:
		return FAIR_COLOR
	return BAD_COLOR
