@tool
extends RefCounted
const ZRAnimBuilder = preload("zen_anim_builder.gd")
const ZRElement = preload("zen_element.gd")
##
## Pure sampling of ONE Godot `Animation` - the document timeline ("zen") or a
## signal's ("sig/<name>").
##
## The Animation is the only stored copy of the keys. This class never ticks
## and never touches the scene tree: it reads curves straight out of the
## resource with bezier_track_interpolate / value_track_interpolate, so a frame
## stays a pure function of (scene, t) and the loop blend can sample a second
## t freely.
##
## Track paths are `Node:prop` for a scalar and `Node:prop:r|g|b` for a colour
## (colour stays RGB-only; alpha is its own scalar track).
##
## CAPTURE SEGMENTS (signals only). A signal's implicit u=0 key is the live pose
## at fire time, unknown when baking. The baker puts a placeholder p0 at t=0 and
## records {path: [t1, p0]} in the Animation meta `zen_capture`; blend() maps the
## baked p0 -> v1 curve onto live -> v1 by its fraction, which is exact for any
## baked curve, overshoot included.
##

const META_CAPTURE := "zen_capture"

var anim: Animation = null
var _idx: Dictionary = {}           ## path String -> track index
var _capture: Dictionary = {}       ## path String -> [t1, p0]


func _init(a: Animation = null) -> void:
	rebuild(a)


func rebuild(a: Animation = null) -> void:
	if a != null: anim = a
	_idx.clear()
	_capture.clear()
	if anim == null: return
	for i in anim.get_track_count():
		var ty := anim.track_get_type(i)
		if ty != Animation.TYPE_BEZIER and ty != Animation.TYPE_VALUE: continue
		if anim.track_get_key_count(i) == 0: continue
		var p := String(anim.track_get_path(i))
		if ZRAnimBuilder.is_ease_path(p): continue     # authoring data, not a curve
		_idx[p] = i
	var cap: Variant = anim.get_meta(META_CAPTURE, {})
	if cap is Dictionary: _capture = (cap as Dictionary).duplicate()


func length() -> float:
	return anim.length if anim != null else 0.0


func has(path: String) -> bool:
	return _idx.has(path)


func has_color(path: String) -> bool:
	return _idx.has(path + ":r")


## Every sampled path, for tests and the gallery.
func paths() -> Array:
	return _idx.keys()


func key_count() -> int:
	var n := 0
	for p in _idx: n += anim.track_get_key_count(_idx[p])
	return n


func _raw(path: String, t: float) -> float:
	var i: int = _idx[path]
	if anim.track_get_type(i) == Animation.TYPE_BEZIER:
		return anim.bezier_track_interpolate(i, t)
	return float(anim.value_track_interpolate(i, t))


## Plain read: the track if it has keys, else `base`.
func scalar(path: String, t: float, base: float) -> float:
	if not _idx.has(path): return base
	return _raw(path, t)


## A stepped (pool index) read. Never interpolated.
func stepped(path: String, t: float, base: float) -> float:
	if not _idx.has(path): return base
	var i: int = _idx[path]
	return float(anim.value_track_interpolate(i, t))


## RGB read, clamped (back/elastic overshoot would otherwise wrap). Alpha is
## always the caller's.
func color(path: String, t: float, base: Color, alpha: float) -> Color:
	if not has_color(path): return Color(base.r, base.g, base.b, alpha)
	return Color(
		clampf(_raw(path + ":r", t), 0.0, 1.0),
		clampf(_raw(path + ":g", t), 0.0, 1.0),
		clampf(_raw(path + ":b", t), 0.0, 1.0), alpha)


## Signal read: ease from the live value `v0` into the track, then hold the
## last key. `shift` is added to the authored track (a pos binding keys offsets
## from the emitted position). Returns `v0` for a track that does not exist.
func blend(path: String, t: float, v0: float, shift := 0.0) -> float:
	if not _idx.has(path): return v0
	var raw := _raw(path, t)
	var cap: Variant = _capture.get(path)
	if cap == null: return shift + raw
	var t1 := float(cap[0])
	var p0 := float(cap[1])
	if t >= t1: return shift + raw
	var v1 := _raw(path, t1)
	var den := v1 - p0
	if absf(den) < 1e-9: return shift + v1
	return v0 + (shift + v1 - v0) * (raw - p0) / den


## Colour form of blend(): RGB mixed to the byte, like ZRElement._mix.
func blend_color(path: String, t: float, c0: Color) -> Color:
	return Color(
		_quant(blend(path + ":r", t, c0.r)),
		_quant(blend(path + ":g", t, c0.g)),
		_quant(blend(path + ":b", t, c0.b)), 1.0)


static func _quant(v: float) -> float:
	return clampf(floorf(v * 255.0 + 0.5), 0.0, 255.0) / 255.0
