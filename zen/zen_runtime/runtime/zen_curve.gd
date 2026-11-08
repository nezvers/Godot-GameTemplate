@tool
extends Resource
##
## A custom easing: a chain of knots from (0,0) to (1,1), each neighbouring pair
## spanning one cubic bezier whose inner controls are the left knot's out-handle
## and the right knot's in-handle.
##
## Direct port of AnimEasePtsEval (src/anim/anim_ease_custom.c). Handles are
## OFFSETS from their knot, in the same units as the knot. Two knots at the same
## x is a hold step; y may overshoot 0..1 freely (that is the point - bop_n_up
## reaches y=1.5).
##
## Not a Godot Curve: Curve clamps to its value range and offers no x-solve, so
## it cannot express overshoot plus hold steps. The math is small; own it.
##

## Knots as [x, y, ix, iy, ox, oy] rows, ascending in x.
@export var knots: Array[PackedFloat32Array] = []


static func _bez1(t: float, c1: float, c2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t


static func _bez1d(t: float, c1: float, c2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * c1 + 6.0 * u * t * (c2 - c1) + 3.0 * t * t * (1.0 - c2)


## Solve x(t) = p for t. Newton first, bisection fallback - the C's scheme.
static func _solve_x(p: float, x1: float, x2: float) -> float:
	var t := p
	for i in 6:
		var d := _bez1d(t, x1, x2)
		if d < 1e-5: break
		t -= (_bez1(t, x1, x2) - p) / d
		t = clampf(t, 0.0, 1.0)
	var err := _bez1(t, x1, x2) - p
	if err < 0.001 and err > -0.001:
		return t
	var lo := 0.0
	var hi := 1.0
	for i in 24:
		t = (lo + hi) * 0.5
		if _bez1(t, x1, x2) < p: lo = t
		else: hi = t
	return t


func sample(p: float) -> float:
	if knots.size() < 2: return p
	if p <= 0.0: return knots[0][1]
	if p >= 1.0: return knots[knots.size() - 1][1]

	var s := 0
	for i in range(knots.size() - 1):
		if p >= knots[i][0]: s = i
		else: break

	var a := knots[s]
	var b := knots[s + 1]
	var span: float = b[0] - a[0]
	if span < 1e-5: return b[1]                 # hold step

	var c1x := clampf(a[4] / span, 0.0, 1.0)            # a.ox
	var c2x := clampf(1.0 + b[2] / span, 0.0, 1.0)      # b.ix
	var t := _solve_x((p - a[0]) / span, c1x, c2x)

	# y is NOT normalised: the delta may be zero or negative.
	var u := 1.0 - t
	var p0: float = a[1]
	var p1: float = a[1] + a[5]                 # a.y + a.oy
	var p2: float = b[1] + b[3]                 # b.y + b.iy
	var p3: float = b[1]
	return u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3

