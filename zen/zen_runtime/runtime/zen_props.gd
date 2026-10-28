@tool
extends RefCounted
##
## The property registry: names, per-kind lists, and the stepped/colour
## classification. One table, consulted by both the element factory and the
## runtime, so the two can never disagree about what a property IS.
##
## Mirrors the PropRow tables in anim_io.c:85+ and AnimPropIsStepped (anim.c).
##

## Scalar props per element kind, in the order the C editor lists them.
const TEXT := ["pos_x", "pos_y", "size", "alpha", "rot", "string",
    "crumble", "crumble_dir", "crumble_spread", "crumble_dist", "crumble_spin"]
const SHAPE := ["pos_x", "pos_y", "w", "h", "alpha", "rot", "scale",
    "outline_alpha", "outline", "shape_id"]
const GLOBAL := ["fade", "bg_alpha"]

## Colour props - RGB only; alpha is ALWAYS a separate scalar track.
const COLOR := ["color", "outline_color", "bg_color"]

## A stepped property keys a POOL INDEX, not a quantity. It is never
## interpolated, never blended and never offset: a value between two entries
## resolves to the wrong entry entirely.
const STEPPED := ["string", "shape_id"]


## Props a pos-param BINDING drives (anim.c:1615-1673). The centre branch
## translates POS only; the corner branch would also stretch W/H, which is
## deferred (no bundled document binds a corner).
const POS := ["pos_x", "pos_y"]
const SIZE := ["w", "h"]


## The property name a prop wears in an Animation track path. Identical except
## where Node2D already owns the name: `scale` is a Vector2 there, and a float
## track on it would be applied to the node itself.
static func track_prop(prop_name: String) -> String:
    return "zen_scale" if prop_name == "scale" else prop_name


static func prop_of_track(track_name: String) -> String:
    return "scale" if track_name == "zen_scale" else track_name


static func is_pos(prop_name: String) -> bool:
    return POS.has(prop_name)


static func is_size(prop_name: String) -> bool:
    return SIZE.has(prop_name)


static func is_stepped(prop_name: String) -> bool:
    return STEPPED.has(prop_name)


static func is_color(prop_name: String) -> bool:
    return COLOR.has(prop_name)


## Every scalar prop a kind can animate. Used by the tests to assert the blend
## reaches all of them.
static func scalars_for(kind: String) -> Array:
    match kind:
        "text": return TEXT
        "shape": return SHAPE
        "global": return GLOBAL
    return []


static func colors_for(kind: String) -> Array:
    match kind:
        "text": return ["color"]
        "shape": return ["color", "outline_color"]
        "global": return ["color", "bg_color"]
    return []
