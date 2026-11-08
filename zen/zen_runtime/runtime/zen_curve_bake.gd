@tool
extends RefCounted
const ZREasing = preload("zen_easing.gd")
##
## Bakes Zen keys ({t, v, ease}) into the keys of a Godot BEZIER track, so the
## curve is stored in the Animation and Godot does the interpolating.
##
## Zen easing is INCOMING: the segment a -> b is shaped by b's ease. Per
## segment the handles sit at dt/3 and 2dt/3, which makes x(s) linear in s, so
## the track's y is any cubic in the segment fraction. A cubic Hermite piece
## with the ease's own end slopes is therefore EXACT for linear/quad/cubic/back
## and a close fit for the rest, which are split until the worst sampled error
## is under TOL (in ease units, i.e. a fraction of the segment's value span).
##
## A zero-span pair (an instant step) cannot be two keys at one time - Godot
## replaces a key at an existing time - so the later key is nudged STEP_EPS.
##

const TOL := 2e-4
const MAX_DEPTH := 10
const STEP_EPS := 1e-4
const SLOPE_H := 1e-4
const CHECKS := 16


## One baked key: {t, v, in: Vector2, out: Vector2} - handles are OFFSETS from
## the key, exactly what Animation.bezier_track_insert_key takes.
static func _key(t: float, v: float, hin := Vector2.ZERO, hout := Vector2.ZERO) -> Dictionary:
	return {"t": t, "v": v, "in": hin, "out": hout}


## Bake scalar keys (ascending in t) to bezier keys. Empty in, empty out.
static func bake(keys: Array) -> Array:
	var out: Array = []
	if keys.is_empty(): return out
	out.append(_key(float(keys[0]["t"]), float(keys[0]["v"])))
	for i in range(1, keys.size()):
		var a: Dictionary = out[out.size() - 1]
		var kb: Dictionary = keys[i]
		var bv := float(kb["v"])
		if float(kb["t"]) <= float(keys[i - 1]["t"]):
			# Instant step: hold the left value, then jump just after it.
			out.append(_key(float(a["t"]) + STEP_EPS, bv))
			continue
		_segment(out, String(kb.get("ease", "linear")), float(a["v"]), bv,
				 float(a["t"]), float(kb["t"]))
	return out


## Append the keys of one segment (a already present as out.back()).
static func _segment(out: Array, ease_name: String, av: float, bv: float,
					 ta: float, tb: float) -> void:
	var pieces: Array = []      # Hermite spans [s0, s1, m0, m1]
	_subdivide(ease_name, 0.0, 1.0, 0, pieces)
	var dt := tb - ta
	var dv := bv - av
	var prev: Dictionary = out[out.size() - 1]
	for pc in pieces:
		var s0: float = pc[0]
		var s1: float = pc[1]
		var m0: float = pc[2]
		var m1: float = pc[3]
		var e1 := _ease(ease_name, s1)
		var ds := s1 - s0
		var span := ds * dt
		prev["out"] = Vector2(span / 3.0, dv * m0 * ds / 3.0)
		var kt := ta + s1 * dt
		var kv := av + dv * e1
		if s1 >= 1.0:
			kt = tb
			kv = bv
		var k := _key(kt, kv, Vector2(-span / 3.0, -dv * m1 * ds / 3.0))
		out.append(k)
		prev = k


static func _ease(ease_name: String, s: float) -> float:
	return ZREasing.apply(ease_name, s)


## Slope d ease / ds at s, one-sided at the ends (second order) and central
## inside, so cubic eases get their exact slopes.
static func _slope(ease_name: String, s: float) -> float:
	var h := SLOPE_H
	if s <= 0.0:
		return (-3.0 * _ease(ease_name, 0.0) + 4.0 * _ease(ease_name, h)
				- _ease(ease_name, 2.0 * h)) / (2.0 * h)
	if s >= 1.0:
		return (3.0 * _ease(ease_name, 1.0) - 4.0 * _ease(ease_name, 1.0 - h)
				+ _ease(ease_name, 1.0 - 2.0 * h)) / (2.0 * h)
	return (_ease(ease_name, minf(s + h, 1.0)) - _ease(ease_name, maxf(s - h, 0.0))) \
		/ (minf(s + h, 1.0) - maxf(s - h, 0.0))


## Recursively split [s0,s1] until a Hermite cubic fits; appends [s0,s1,m0,m1].
static func _subdivide(ease_name: String, s0: float, s1: float, depth: int, out: Array) -> void:
	var m0 := _slope(ease_name, s0)
	var m1 := _slope(ease_name, s1)
	if _fits(ease_name, s0, s1, m0, m1):
		out.append([s0, s1, m0, m1])
		return
	if depth >= MAX_DEPTH:
		# A vertical tangent (circ) or a kink would put a huge slope into a
		# sliver of a piece; the secant keeps the handles finite.
		var sec := (_ease(ease_name, s1) - _ease(ease_name, s0)) / (s1 - s0)
		out.append([s0, s1, sec, sec])
		return
	var mid := (s0 + s1) * 0.5
	_subdivide(ease_name, s0, mid, depth + 1, out)
	_subdivide(ease_name, mid, s1, depth + 1, out)


static func _fits(ease_name: String, s0: float, s1: float, m0: float, m1: float) -> bool:
	var e0 := _ease(ease_name, s0)
	var e1 := _ease(ease_name, s1)
	var ds := s1 - s0
	for i in range(1, CHECKS):
		var u := float(i) / CHECKS
		var u2 := u * u
		var u3 := u2 * u
		var h := (2.0 * u3 - 3.0 * u2 + 1.0) * e0 + (u3 - 2.0 * u2 + u) * ds * m0 \
			+ (-2.0 * u3 + 3.0 * u2) * e1 + (u3 - u2) * ds * m1
		if absf(h - _ease(ease_name, s0 + u * ds)) > TOL: return false
	return true


## Nudge a key list so no two keys share (or invert) a time. Stepped (value)
## tracks need this too.
static func separate(times: Array) -> Array:
	var out: Array = []
	for i in times.size():
		var t := float(times[i])
		if i > 0 and t <= float(out[i - 1]): t = float(out[i - 1]) + STEP_EPS
		out.append(t)
	return out
