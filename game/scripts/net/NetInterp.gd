## Smooth playback of positions reported over the network (enemy snapshots,
## teammate updates). Samples carry the sender's clock; they are shown a fixed
## delay behind the newest, interpolated between the two around that moment, so
## late or bunched packets don't make the copy stop, jump or turn back.
##
## The sender's clock is mapped to ours with an offset that follows the fastest
## arrival seen (the one least delayed by the network), slowly forgetting it so
## a changing route can't leave it stuck.
class_name NetInterp
extends RefCounted

## Shown this far behind the newest sample: two 20 Hz updates, so one lost or
## late packet still has a sample after it to move towards.
const DELAY:float = 0.1
## Past the newest sample the copy keeps going this long, then stops.
const MAX_EXTRAPOLATE:float = 0.1
## Jumps this far (teleports, respawns) aren't smoothed.
const SNAP_DISTANCE:float = 64.0
const MAX_SAMPLES:int = 12
## How fast a too-early offset relaxes back (seconds per second).
const OFFSET_RELAX:float = 0.02

## [sender_time, position] oldest first
var _samples:Array = []
var _offset:float
var _has_offset:bool
var _last_local:float

## Local time now, in seconds.
static func now()->float:
	return Time.get_ticks_usec() / 1000000.0

func clear()->void:
	_samples.clear()
	_has_offset = false

func is_empty()->bool:
	return _samples.is_empty()

## A position the sender had at its time `sent`.
func push(sent:float, at:Vector2, local:float = now())->void:
	if !is_finite(sent) || !at.is_finite():
		return
	# offset: local - sender for the least delayed packet, relaxing over time
	var _arrival:float = local - sent
	if !_has_offset:
		_offset = _arrival
		_has_offset = true
	else:
		_offset = minf(_offset + OFFSET_RELAX * maxf(local - _last_local, 0.0), _arrival)
	_last_local = local
	if !_samples.is_empty():
		var _newest:Array = _samples[-1]
		if sent <= float(_newest[0]):
			# out of order or repeated: unreliable_ordered drops older ones, but be safe
			return
		if (_newest[1] as Vector2).distance_to(at) > SNAP_DISTANCE:
			_samples.clear()
	_samples.append([sent, at])
	while _samples.size() > MAX_SAMPLES:
		_samples.pop_front()

## Sender time currently being shown.
func render_time(local:float = now())->float:
	return local - _offset - DELAY

## Where the copy should be now.
func position(local:float = now())->Vector2:
	if _samples.is_empty():
		return Vector2.INF
	var _t:float = render_time(local)
	var _first:Array = _samples[0]
	if _t <= float(_first[0]):
		return _first[1]
	for _i:int in range(1, _samples.size()):
		var _b:Array = _samples[_i]
		if _t <= float(_b[0]):
			var _a:Array = _samples[_i - 1]
			var _span:float = float(_b[0]) - float(_a[0])
			var _w:float = (_t - float(_a[0])) / _span if _span > 0.0 else 1.0
			return (_a[1] as Vector2).lerp(_b[1], _w)
	# past the newest: keep the last velocity a little while
	var _newest:Array = _samples[-1]
	var _ahead:float = minf(_t - float(_newest[0]), MAX_EXTRAPOLATE)
	return (_newest[1] as Vector2) + velocity_at_end() * _ahead

## Velocity between the two newest samples (px/s).
func velocity_at_end()->Vector2:
	if _samples.size() < 2:
		return Vector2.ZERO
	var _a:Array = _samples[-2]
	var _b:Array = _samples[-1]
	var _span:float = float(_b[0]) - float(_a[0])
	if _span <= 0.0:
		return Vector2.ZERO
	return ((_b[1] as Vector2) - (_a[1] as Vector2)) / _span

## Velocity of the shown motion right now (px/s).
func velocity(local:float = now())->Vector2:
	if _samples.size() < 2:
		return Vector2.ZERO
	var _t:float = render_time(local)
	for _i:int in range(1, _samples.size()):
		var _b:Array = _samples[_i]
		if _t <= float(_b[0]):
			var _a:Array = _samples[_i - 1]
			var _span:float = float(_b[0]) - float(_a[0])
			return ((_b[1] as Vector2) - (_a[1] as Vector2)) / _span if _span > 0.0 else Vector2.ZERO
	var _newest:Array = _samples[-1]
	if _t - float(_newest[0]) > MAX_EXTRAPOLATE:
		return Vector2.ZERO
	return velocity_at_end()
