@tool
extends RefCounted
const ZRSignalBus = preload("zen_signal_bus.gd")
##
## The shape of one authored signal (a ZRSignalBus.signals_data entry), and
## the one place that upgrades older data to it.
##
## A signal is three independent choices:
##
##   - its EFFECT: `length`, `terminal`, `replay` and the keyed `targets` (plus
##     the stage `seq` fan-out) - what it animates;
##   - its TRIGGER: when the canvas fires it by itself (`code` = never, only
##     fire() / ZenSignals.emit());
##   - its POINT: how the elements in `point_elems` react to a position.
##
## The C original spread the last two over interdependent flags (usesPos,
## posAnchor, replay hidden under "position param") plus a fourth keyed type
## (posparam offset keys) and left the triggers to hand-written game code. Here
## each is one field, so every scenario is a value, not code:
##
##   ripple born at a click     trigger=press    point=anchor
##   move to the mouse-up spot  trigger=release  point=seek
##   follow the mouse           trigger=press    point=follow
##   on animation end / loop    trigger=end      (every_loop)
##   one after another          then=<name>
##

const TRIGGERS := ["code", "press", "release", "end"]

## none:   the point is ignored.
## anchor: a CONSTANT translation so the bound centre lands on the point at
##         fire time - the authored path plays "born at the cursor".
## seek:   the centre eases from the captured pose to the point over `length`.
## follow: seek, but the point is read again every frame, and the element keeps
##         tracking it after `length` until another signal supersedes it.
const POINTS := ["none", "anchor", "seek", "follow"]

const DEFAULT_POINT_EASE := "sineOut"


static func defaults(signal_name := "") -> Dictionary:
    return {"name": signal_name, "length": 1.0, "terminal": false, "replay": false,
            "trigger": "code", "every_loop": false, "then": "",
            "point": "none", "point_elems": [], "point_ease": DEFAULT_POINT_EASE,
            "targets": [], "uses_seq": false, "seq_mult": 0.0,
            "seq_targets": [], "seq_keys": []}


## Fill missing fields and upgrade a legacy entry IN PLACE. Idempotent.
##
## Legacy = uses_pos / pos_anchor / pos_params. A pos-param's keyed offsets
## collapse to one constant offset and one ease (its LAST key's), which is all
## every bundled document ever used; CORNER slots were never implemented and
## are dropped loudly.
static func normalize(sig: Dictionary) -> Dictionary:
    if sig.has("uses_pos") or sig.has("pos_params"):
        var uses := bool(sig.get("uses_pos", false))
        if not sig.has("point"):
            sig["point"] = "none" if not uses \
                else ("anchor" if bool(sig.get("pos_anchor", false)) else "seek")
        if not sig.has("point_elems"):
            var elems: Array = []
            for pp in sig.get("pos_params", []):
                if int(pp.get("slot", 0)) != 0:
                    push_warning("zen: signal '%s' drops a corner binding on '%s'"
                        % [sig.get("name", ""), pp.get("elem", "")])
                    continue
                var off := Vector2.ZERO
                var keys: Array = pp.get("keys", [])
                if not keys.is_empty():
                    off = keys[-1].get("off", Vector2.ZERO)
                    sig["point_ease"] = String(keys[-1].get("ease", DEFAULT_POINT_EASE))
                elems.append({"elem": String(pp["elem"]), "off": off})
            sig["point_elems"] = elems
        sig.erase("uses_pos")
        sig.erase("pos_anchor")
        sig.erase("pos_params")
    var d := defaults()
    for k in d:
        if not sig.has(k): sig[k] = d[k]
    if not TRIGGERS.has(String(sig["trigger"])): sig["trigger"] = "code"
    if not POINTS.has(String(sig["point"])): sig["point"] = "none"
    return sig


## The signal chained after `sig`, or "". A terminal signal ends the instance
## and a follow never completes, so neither chains.
static func chained(sig: Dictionary) -> String:
    if bool(sig.get("terminal", false)) or String(sig.get("point", "")) == "follow":
        return ""
    return String(sig.get("then", ""))


## Does this signal need pointer input to do anything a code call cannot?
static func wants_pointer(sig: Dictionary) -> bool:
    var tr := String(sig.get("trigger", ""))
    return tr == "press" or tr == "release" or String(sig.get("point", "")) == "follow"
