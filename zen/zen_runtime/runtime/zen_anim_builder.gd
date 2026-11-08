@tool
extends RefCounted
const ZRCanvas = preload("zen_canvas.gd")
const ZRCurveBake = preload("zen_curve_bake.gd")
const ZRElement = preload("zen_element.gd")
const ZRProps = preload("zen_props.gd")
const ZRTimeline = preload("zen_timeline.gd")
##
## Assembles the AnimationPlayer a Zen scene SAVES, and keeps it the single
## source of truth for the keys.
##
## WHAT IS IN THE SCENE
##
##   AnimationPlayer           root_node ".." (the canvas)
##     library ""    "zen"          the document timeline
##     library "sig" one per signal, `length` seconds long
##
## "zen" holds one track per animated property. Scalars are BEZIER tracks at
## `Node:prop`; colours are three bezier tracks `Node:prop:r|g|b` (RGB only -
## alpha has its own scalar track); stepped props (`string`, `shape_id`) are
## VALUE tracks with nearest interpolation, because a pool index must never be
## interpolated. Zen's easings are BAKED into the bezier handles by
## ZRCurveBake - Godot does the interpolating, and what is stored is what
## plays. The clock fields are markers: `intro_end`, `outro_start` and
## `pause_N[_once]`, so dragging them in Godot's panel edits the document.
##
## Each eased prop also gets an EASE track at `Node:zen_ease_<prop>`: a
## discrete String value track holding one key per AUTHORED key, at that key's
## time, naming its incoming ease. So Zen's {t, v, ease} is split across two
## tracks - {t, v} in the bezier, {t, ease} beside it - and the bezier keys
## whose time has no ease key are the extra fit keys ZRCurveBake inserted for
## a non-cubic ease. One ease track serves all three channels of a colour.
## A bezier with no ease track reads as raw: every key authored, ease "bezier"
## (see ZenKeyOps). Stepped props have none - they never interpolate.
##
## A signal's keys sit at `u * length` seconds, so its Animation shows real
## time. Its sequence envelope is the `Signals:seq` track. See ZRTimeline for
## the capture rule.
##
## The retained `_anim_pose` method track keeps the old "the Animation owns
## time" contract: it calls canvas.pose_looping(), the one resolver.
##

const ANIM := "zen"
const LIB := ""
const SIG_LIB := "sig"

const M_INTRO := "intro_end"
const M_OUTRO := "outro_start"
const M_PAUSE := "pause_"
const ONCE := "_once"

const SEQ_NODE := "Signals"
const SEQ_PROP := "seq"

## Property-name prefix of an ease track (`Node:zen_ease_<prop>`).
const EASE_PREFIX := "zen_ease_"
## The ease of a key whose handles are kept as they are, never rebaked.
const EASE_RAW := "bezier"


# ---------------------------------------------------------------------------
#  Naming
# ---------------------------------------------------------------------------

## AnimationLibrary names reject / : , [ and an empty string.
static func sig_anim_name(signal_name: String) -> String:
	var out := ""
	for ch in signal_name:
		out += "_" if "/:,[]".contains(ch) else ch
	return out if not out.is_empty() else "signal"


## Path of the Animation a signal lives in, as AnimationPlayer addresses it.
static func sig_path(signal_name: String) -> String:
	return "%s/%s" % [SIG_LIB, sig_anim_name(signal_name)]


## The NODE NAME that owns (elem, prop): the authored element name is matched
## against `elem_name` and a global's two halves are told apart by prop.
static func node_name_for(canvas: ZRCanvas, elem: String, prop: String) -> String:
	for e in canvas.elements():
		var el := e as ZRElement
		if el.elem_name == elem and el.owns(prop): return String(el.name)
	return elem


## The ease track of (node, prop): `Node:zen_ease_<prop>`.
static func ease_path(node_name: String, prop: String) -> String:
	return "%s:%s%s" % [node_name, EASE_PREFIX, prop]


## Is `path` an ease track rather than a value track?
static func is_ease_path(path: String) -> bool:
	return path.get_slice(":", 1).begins_with(EASE_PREFIX)


## Does `prop` carry an ease track when keyed? Stepped props never do.
static func has_ease(prop: String) -> bool:
	return not ZRProps.is_stepped(prop)


# ---------------------------------------------------------------------------
#  The document timeline
# ---------------------------------------------------------------------------

static func bake_timeline(canvas: ZRCanvas, looping := true) -> Animation:
	var anim := Animation.new()
	# The FULL clock, not the play section: the outro stays visible on the
	# timeline (it is authored data) though it is never rendered.
	anim.length = maxf(canvas.duration, 0.0001)
	anim.step = 0.0166667                                  # 1/60, the edit grid
	# setup_animation_player sets the real mode (LOOP_LINEAR vs LOOP_NONE).
	anim.loop_mode = Animation.LOOP_NONE

	write_markers(anim, canvas)

	var tr := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(tr, NodePath("."))
	anim.track_insert_key(tr, 0.0, {"method": "_anim_pose", "args": [looping]})

	for e in canvas.elements():
		var el := e as ZRElement
		for prop in el.tracks:
			var keys: Array = el.tracks[prop]
			if keys.is_empty() or not el.owns(String(prop)): continue
			var path := el.track_path(String(prop))
			if ZRProps.is_stepped(String(prop)):
				_add_stepped(anim, path, keys)
				continue
			if ZRProps.is_color(String(prop)):
				_add_color(anim, path, keys)
			else:
				_add_scalar(anim, path, keys)
			add_ease(anim, ease_path(String(el.name), String(prop)), keys)
	return anim


## Surface the clock fields as markers. 0 means ABSENT for intro/outro
## (AnimDocOutroStart), so a 0 is not a marker at the origin.
static func write_markers(anim: Animation, canvas: ZRCanvas) -> void:
	if not anim.has_method("add_marker"): return            # pre-4.5 fallback
	for n in anim.get_marker_names():
		anim.remove_marker(n)
	if canvas.intro_end > 0.0:
		anim.add_marker(M_INTRO, clampf(canvas.intro_end, 0.0, anim.length))
	if canvas.outro_start > 0.0:
		anim.add_marker(M_OUTRO, clampf(canvas.outro_start, 0.0, anim.length))
	var n := 0
	for p in canvas.pauses:
		n += 1
		var nm := "%s%d%s" % [M_PAUSE, n, ONCE if bool(p.get("once", false)) else ""]
		anim.add_marker(nm, clampf(float(p["t"]), 0.0, anim.length))


## Read the clock back OUT of the markers and length, so editing them in Godot
## edits the document. Returns true when something changed.
static func sync_markers(anim: Animation, canvas: ZRCanvas) -> bool:
	if anim == null: return false
	var changed := false
	if not is_equal_approx(anim.length, canvas.duration):
		canvas.duration = anim.length
		changed = true
	if not anim.has_method("get_marker_names"): return changed
	var names: PackedStringArray = anim.get_marker_names()
	# Absent marker = unset (0), so deleting one in Godot clears it.
	var intro := anim.get_marker_time(M_INTRO) if names.has(M_INTRO) else 0.0
	var outro := anim.get_marker_time(M_OUTRO) if names.has(M_OUTRO) else 0.0
	if not is_equal_approx(intro, canvas.intro_end):
		canvas.intro_end = intro
		changed = true
	if not is_equal_approx(outro, canvas.outro_start):
		canvas.outro_start = outro
		changed = true
	var marks: Array = []
	for nm in names:
		if not String(nm).begins_with(M_PAUSE): continue
		marks.append({"t": anim.get_marker_time(nm), "once": String(nm).ends_with(ONCE)})
	marks.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	if not _same_pauses(marks, canvas.pauses):
		canvas.pauses = marks
		changed = true
	return changed


static func _same_pauses(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if not is_equal_approx(float(a[i]["t"]), float(b[i]["t"])): return false
		if bool(a[i].get("once", false)) != bool(b[i].get("once", false)): return false
	return true


# ---------------------------------------------------------------------------
#  Tracks
# ---------------------------------------------------------------------------

static func _add_scalar(anim: Animation, path: String, keys: Array) -> void:
	_insert_bezier(anim, path, ZRCurveBake.bake(keys))


static func _insert_bezier(anim: Animation, path: String, baked: Array) -> void:
	var tr := anim.add_track(Animation.TYPE_BEZIER)
	anim.track_set_path(tr, NodePath(path))
	for k in baked:
		anim.bezier_track_insert_key(tr, k["t"], k["v"], k["in"], k["out"])


static func _add_color(anim: Animation, path: String, keys: Array) -> void:
	for ch in ["r", "g", "b"]:
		var ck: Array = []
		for k in keys:
			var c: Color = k["c"]
			ck.append({"t": k["t"], "v": c[ch], "ease": k.get("ease", "linear")})
		_insert_bezier(anim, "%s:%s" % [path, ch], ZRCurveBake.bake(ck))


static func _add_stepped(anim: Animation, path: String, keys: Array) -> void:
	var tr := add_discrete(anim, path)
	var times: Array = []
	for k in keys: times.append(float(k["t"]))
	times = ZRCurveBake.separate(times)
	for i in keys.size():
		anim.track_insert_key(tr, times[i], float(keys[i]["v"]))


## A nearest/discrete VALUE track - what a stepped prop and an ease track are.
static func add_discrete(anim: Animation, path: String) -> int:
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath(path))
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(tr, Animation.UPDATE_DISCRETE)
	return tr


## The ease track for `keys`: one String key per authored key, at the time the
## baker gave it (separate() is the nudge bake() applies to an instant step).
## The first key's ease shapes no segment; it is stored so the key reads back
## as authored.
static func add_ease(anim: Animation, path: String, keys: Array) -> void:
	var tr := add_discrete(anim, path)
	var times: Array = []
	for k in keys: times.append(float(k["t"]))
	times = ZRCurveBake.separate(times)
	for i in keys.size():
		anim.track_insert_key(tr, times[i], String(keys[i].get("ease", "linear")))


# ---------------------------------------------------------------------------
#  Signals
# ---------------------------------------------------------------------------

## One Animation for an authored signal. `node_of` is Callable(elem, prop) ->
## node name; the default is the authored name itself.
static func bake_signal(sig: Dictionary, node_of := Callable()) -> Animation:
	var length := float(sig.get("length", 0.0))
	var span := length if length > 0.0 else 1.0     # length 0: instant, lands on u=1
	var anim := Animation.new()
	anim.length = span
	anim.step = 0.0166667
	var capture: Dictionary = {}

	for tg in sig.get("targets", []):
		var prop := String(tg["prop"])
		var keys: Array = tg.get("keys", [])
		if keys.is_empty() or ZRProps.is_stepped(prop): continue
		var node := _node(node_of, String(tg["elem"]), prop)
		var path := "%s:%s" % [node, ZRProps.track_prop(prop)]
		var scaled: Array = []
		if ZRProps.is_color(prop):
			for ch in ["r", "g", "b"]:
				var ck: Array = []
				for k in keys:
					var c: Color = k["c"]
					ck.append({"t": k["t"], "v": c[ch], "ease": k.get("ease", "linear")})
				scaled = _signal_track(anim, "%s:%s" % [path, ch], ck, span, true, capture)
		else:
			scaled = _signal_track(anim, path, keys, span, true, capture)
		# The same authored keys as the timeline's, so ZenKeyOps edits a
		# signal exactly like the document (the capture placeholder included).
		add_ease(anim, ease_path(node, prop), scaled)

	var seq_keys: Array = sig.get("seq_keys", [])
	if not seq_keys.is_empty():
		# The envelope starts from a constant 0, so it is a real key, not a capture.
		_signal_track(anim, "%s:%s" % [SEQ_NODE, SEQ_PROP], seq_keys, span, false, capture)

	if not capture.is_empty(): anim.set_meta(ZRTimeline.META_CAPTURE, capture)
	return anim


static func _node(node_of: Callable, elem: String, prop: String) -> String:
	return String(node_of.call(elem, prop)) if node_of.is_valid() else elem


## Bake `keys` (t in u) onto `anim` at u*span seconds. With `capture`, a first
## key past u=0 gets a placeholder key at t=0 and a capture-meta entry.
## Returns the keys as baked, in seconds, placeholder first.
static func _signal_track(anim: Animation, path: String, keys: Array, span: float,
						  capture_start: bool, capture: Dictionary) -> Array:
	var scaled: Array = []
	for k in keys:
		scaled.append({"t": float(k["t"]) * span, "v": float(k["v"]),
					   "ease": k.get("ease", "linear")})
	if float(scaled[0]["t"]) > 0.0:
		var v1 := float(scaled[0]["v"])
		var p0 := 0.0 if absf(v1) > 1e-6 else 1.0
		if capture_start: capture[path] = [float(scaled[0]["t"]), p0]
		else: p0 = 0.0
		scaled.push_front({"t": 0.0, "v": p0, "ease": "linear"})
	_insert_bezier(anim, path, ZRCurveBake.bake(scaled))
	return scaled


# ---------------------------------------------------------------------------
#  Installing into a canvas
# ---------------------------------------------------------------------------

## The Animation a signal's keys live in, or null.
static func signal_anim(canvas: Node, signal_name: String) -> Animation:
	var ap := find_player(canvas)
	if ap == null or not ap.has_animation_library(SIG_LIB): return null
	var lib := ap.get_animation_library(SIG_LIB)
	var an := sig_anim_name(signal_name)
	return lib.get_animation(an) if lib.has_animation(an) else null


## The canvas's AnimationPlayer, or null.
static func find_player(canvas: Node) -> AnimationPlayer:
	for c in canvas.get_children():
		if c is AnimationPlayer: return c
	return null


## Bake the canvas's in-memory keys into a real AnimationPlayer child, owned by
## the canvas so it packs. Idempotent: it replaces what it made before.
##
## `strip` drops the signal keys from the bus once they live in the player, so
## the scene stores them in exactly one place.
static func install(canvas: ZRCanvas, strip := true) -> AnimationPlayer:
	var ap := find_player(canvas)
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		canvas.add_child(ap)
		# Like the bus, a non-element child: a z index is not spent on it.
		ap.owner = canvas.owner if canvas.owner != null else canvas
	ap.root_node = NodePath("..")
	ap.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE

	var lib := _library(ap, LIB)
	if lib.has_animation(ANIM): lib.remove_animation(ANIM)
	lib.add_animation(ANIM, bake_timeline(canvas, canvas.loop_smooth))

	var bus := canvas.bus()
	if bus != null:
		var slib := _library(ap, SIG_LIB)
		for s in bus.signals_data:
			var sig: Dictionary = s
			var nm := sig_anim_name(String(sig.get("name", "")))
			if slib.has_animation(nm): slib.remove_animation(nm)
			slib.add_animation(nm, bake_signal(sig,
				func(e, p): return node_name_for(canvas, e, p)))
			if strip: strip_keys(sig)
	# assigned_animation, not current_animation: the latter PLAYS it.
	ap.assigned_animation = ANIM
	return ap


static func _library(ap: AnimationPlayer, nm: String) -> AnimationLibrary:
	if ap.has_animation_library(nm): return ap.get_animation_library(nm)
	var lib := AnimationLibrary.new()
	ap.add_animation_library(nm, lib)
	return lib


## The authored signal with its key arrays emptied: the shape stored in the
## scene once the keys are in the player.
static func strip_keys(sig: Dictionary) -> void:
	for tg in sig.get("targets", []): tg["keys"] = []
	sig["seq_keys"] = []
