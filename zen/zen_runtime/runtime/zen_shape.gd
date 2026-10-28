@tool
extends ZRElement
const ZRElement = preload("zen_element.gd")
const ZRPixelShape = preload("zen_pixel_shape.gd")
##
## The AE_SHAPE element kind. One _draw() switching on shape_kind, ported from
## DrawShapeElem (src/anim/anim.c:1296-1413).
##
## Geometry notes that are not guessable from the property names:
##   - every shape is CENTRE-anchored and rotates about its own centre;
##   - `scale` is a uniform multiplier applied on top of w/h AND the outline
##     thickness, so a scaled shape keeps its authored rim-to-body proportion;
##   - SQUARE uses h for BOTH axes (w is ignored);
##   - LINE is length=w, thickness=h, drawn in the FILL colour with round caps,
##     and its half-length is projected per-axis so a corner-to-corner line
##     stays corner-to-corner when the canvas aspect changes;
##   - fill alpha and outline alpha are INDEPENDENT tracks;
##   - CUSTOM draws a ZRPixelShape stretched over the w x h box: fill cells
##     tinted by `color`, outline cells by `outline_color`. Its outline is
##     pixel data, not a stroke, so the `outline` thickness does not apply.
##     Which shape: the stepped `shape_id` track indexes `shape_refs`; with no
##     track (or a negative key) it is `shape`. A missing one draws a magenta
##     box with a diagonal, so the problem shows in exports too.
##

enum Kind { RECT, CIRCLE, SQUARE, RHOMBUS, TRIANGLE, LINE, CUSTOM }

const KIND_NAMES := ["rect", "circle", "square", "rhombus", "triangle", "line", "custom"]
const ELLIPSE_SEGS := 36

@export var shape_kind: Kind = Kind.RECT
@export var size_frac := Vector2(0.2, 0.2)
@export var scale_base := 1.0
@export var color_base := Color(1, 1, 1, 1)
@export var outline_color_base := Color(1, 1, 1, 1)
@export var outline_base := 0.0
## Circle-only: stroke as a true annulus instead of a faceted polygon loop, so
## a thin rim does not shimmer as it animates.
@export var outline_crisp := false

## CUSTOM only: the rest-pose pixel shape.
@export var shape: ZRPixelShape:
    set(v):
        if shape != null and shape.changed.is_connected(queue_redraw):
            shape.changed.disconnect(queue_redraw)
        shape = v
        if shape != null: shape.changed.connect(queue_redraw)
        queue_redraw()
## The name `shape` was authored under, kept so a missing asset can be named.
@export var shape_name := ""
## CUSTOM only: the shapes a `shape_id` track switches between, by index.
@export var shape_refs: Array[ZRPixelShape] = []

## A `shape_id` key value meaning "the authored shape no longer exists".
const SHAPE_MISSING := -2.0

var _t := 0.0


func zen_kind() -> String:
    return "shape"


func base_scalar(prop_name: String) -> float:
    match prop_name:
        "w": return size_frac.x
        "h": return size_frac.y
        "alpha": return color_base.a
        "outline_alpha": return outline_color_base.a
        "scale": return scale_base
        "outline": return outline_base
        # -1: no track override, draw `shape` (the C's AnimShapePoolFindByName
        # fallback for a negative AP_S_SHAPE).
        "shape_id": return -1.0
    return super.base_scalar(prop_name)


func base_color(prop_name: String) -> Color:
    return outline_color_base if prop_name == "outline_color" else color_base


func set_base_scalar(prop_name: String, v: float) -> bool:
    match prop_name:
        "w": size_frac.x = v
        "h": size_frac.y = v
        "alpha": color_base.a = v
        "outline_alpha": outline_color_base.a = v
        "scale": scale_base = v
        "outline": outline_base = v
        _: return super.set_base_scalar(prop_name, v)
    queue_redraw()
    return true


func set_base_color(prop_name: String, c: Color) -> bool:
    match prop_name:
        "color": color_base = _rgb(c, color_base.a)
        "outline_color": outline_color_base = _rgb(c, outline_color_base.a)
        _: return false
    queue_redraw()
    return true


static func kind_from_name(n: String) -> Kind:
    var i := KIND_NAMES.find(n)
    return (i if i >= 0 else 0) as Kind


func _pose(t: float) -> void:
    _t = t


## The pixel shape showing at `t`, or null when it is missing.
func shape_at(t: float) -> ZRPixelShape:
    var idx := prop("shape_id", t, -1.0)
    if idx <= SHAPE_MISSING + 0.5: return null
    if idx < 0.0: return shape
    var i := int(idx + 0.5)
    return shape_refs[i] if i < shape_refs.size() else null


func bounds_px(t: float) -> Rect2:
    var sc := maxf(prop("scale", t, scale_base), 0.0)
    var w_f := prop("w", t, size_frac.x) * sc
    var h_f := prop("h", t, size_frac.y) * sc
    var rot := deg_to_rad(prop("rot", t, rot_base))
    var c := center_px(t)
    var hw := _uw() * w_f * 0.5
    var hh := _uh() * h_f * 0.5
    if shape_kind == Kind.LINE:
        var d := Vector2(_uw() * w_f * 0.5 * cos(rot), _uh() * w_f * 0.5 * sin(rot))
        return Rect2(c - d, Vector2.ZERO).expand(c + d).grow(maxf(_uh() * h_f, 1.0) * 0.5)
    if shape_kind == Kind.SQUARE: hw = hh
    return _box(c, [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)], rot)


## The drawn geometry, the same as _draw(): the line's stroke, the rim of the
## outlined kinds, and a custom shape's non-empty cells.
func hit_px(p: Vector2, t: float, slop: float) -> bool:
    var sc := maxf(prop("scale", t, scale_base), 0.0)
    var w_f := prop("w", t, size_frac.x) * sc
    var h_f := prop("h", t, size_frac.y) * sc
    var rot := deg_to_rad(prop("rot", t, rot_base))
    var c := center_px(t)
    var hw := _uw() * w_f * 0.5
    var hh := _uh() * h_f * 0.5
    match shape_kind:
        Kind.LINE:
            var d := Vector2(hw * cos(rot), _uh() * w_f * 0.5 * sin(rot))
            var q := Geometry2D.get_closest_point_to_segment(p, c - d, c + d)
            return q.distance_to(p) <= maxf(_uh() * h_f, 1.0) * 0.5 + slop
        Kind.CIRCLE:
            var q := _unrotate(p, c, rot)
            var rx := hw + slop
            var ry := hh + slop
            return rx > 0.0 and ry > 0.0 and (q.x * q.x) / (rx * rx) + (q.y * q.y) / (ry * ry) <= 1.0
        Kind.CUSTOM:
            var q := _unrotate(p, c, rot)
            if absf(q.x) > hw + slop or absf(q.y) > hh + slop: return false
            var ps := shape_at(t)
            if ps == null or hw <= 0.0 or hh <= 0.0: return true
            # The cell under `p`, or any within `slop` of it.
            var cell := Vector2(hw * 2.0 / ps.size.x, hh * 2.0 / ps.size.y)
            var lo := ((q - Vector2(slop, slop) + Vector2(hw, hh)) / cell).floor()
            var hi := ((q + Vector2(slop, slop) + Vector2(hw, hh)) / cell).floor()
            for y in range(int(lo.y), int(hi.y) + 1):
                for x in range(int(lo.x), int(hi.x) + 1):
                    if ps.get_cell(x, y) != ZRPixelShape.EMPTY: return true
            return false
    var rim := _rim(hw, hh, rot)
    var lp := p - c
    if Geometry2D.is_point_in_polygon(lp, rim): return true
    for i in rim.size():
        var q := Geometry2D.get_closest_point_to_segment(lp, rim[i], rim[(i + 1) % rim.size()])
        if q.distance_to(lp) <= slop: return true
    return false


func shows_at(t: float) -> bool:
    if prop("scale", t, scale_base) <= 0.0: return false
    if prop("alpha", t, color_base.a) > 0.0: return true
    if shape_kind == Kind.LINE or prop("outline_alpha", t, outline_color_base.a) <= 0.0: return false
    return shape_kind == Kind.CUSTOM \
        or _uh() * prop("outline", t, outline_base) * prop("scale", t, scale_base) >= 0.5


func _draw() -> void:
    var t := _t
    var fill_a := prop("alpha", t, color_base.a)
    var out_a := prop("outline_alpha", t, outline_color_base.a)
    var sc := maxf(prop("scale", t, scale_base), 0.0)

    var uw := _uw()
    var uh := _uh()
    var thick_px := uh * prop("outline", t, outline_base) * sc

    # Nothing to draw: no fill, and no outline thick enough to land a pixel.
    # A custom shape's outline is pixel data, visible whenever its alpha is.
    if shape_kind == Kind.CUSTOM:
        if fill_a <= 0.0 and out_a <= 0.0: return
    elif fill_a <= 0.0 and (out_a <= 0.0 or thick_px < 0.5): return

    var w_f := prop("w", t, size_frac.x) * sc
    var h_f := prop("h", t, size_frac.y) * sc
    var rot := deg_to_rad(prop("rot", t, rot_base))

    var fill := prop_color("color", t, color_base, fill_a)
    var line := prop_color("outline_color", t, outline_color_base, out_a)

    var c := Vector2.ZERO       # the node sits at the centre (see mirrors_position)
    var hw := uw * w_f * 0.5
    var hh := uh * h_f * 0.5

    if shape_kind == Kind.LINE:
        if fill.a <= 0.0: return
        # Half-length projected per axis (see class header).
        var hlx := maxf(uw * w_f * 0.5, 0.0)
        var hly := maxf(uh * w_f * 0.5, 0.0)
        var th := maxf(uh * h_f, 1.0)
        var a := c - Vector2(hlx * cos(rot), hly * sin(rot))
        var b := c + Vector2(hlx * cos(rot), hly * sin(rot))
        draw_line(a, b, fill, th, true)
        draw_circle(a, th * 0.5, fill)      # round caps
        draw_circle(b, th * 0.5, fill)
        return

    if shape_kind == Kind.CUSTOM:
        _draw_custom(t, c, hw, hh, rot, fill, line)
        return

    # Crisp circle: filled fan plus a smooth annulus stroke.
    if shape_kind == Kind.CIRCLE and outline_crisp:
        var radius := (hw + hh) * 0.5
        if fill.a > 0.0:
            draw_circle(c, radius, fill)
        if thick_px >= 0.5 and line.a > 0.0:
            # draw_arc strokes centred on its radius, so step in by half the
            # width to land the rim inside the shape like DrawRing does.
            var mid := maxf(radius - thick_px * 0.5, 0.0)
            draw_arc(c, mid, 0.0, TAU, ELLIPSE_SEGS, line, thick_px, true)
        return

    var rim := _rim(hw, hh, rot)
    if fill.a > 0.0:
        draw_colored_polygon(rim, fill)
    if thick_px >= 0.5 and line.a > 0.0:
        var loop := rim.duplicate()
        loop.append(rim[0])
        draw_polyline(loop, line, thick_px, true)


func _draw_custom(t: float, c: Vector2, hw: float, hh: float, rot: float,
                  fill: Color, line: Color) -> void:
    var box := Rect2(-hw, -hh, hw * 2.0, hh * 2.0)
    # Set on the canvas item rather than the `texture_filter` property so it
    # is never written into a saved scene.
    RenderingServer.canvas_item_set_default_texture_filter(
        get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
    draw_set_transform(c, rot)
    var ps := shape_at(t)
    if ps == null:
        var warn := Color(1, 0, 1, fill.a if fill.a > 0.0 else 1.0)
        draw_rect(box, warn, false, 2.0)
        draw_line(box.position, box.end, warn, 2.0)
    else:
        # Both stencils cover the same box. Nearest filtering keeps the texels
        # square however far the box stretches them.
        if fill.a > 0.0: draw_texture_rect(ps.fill_texture(), box, false, fill)
        if line.a > 0.0: draw_texture_rect(ps.outline_texture(), box, false, line)
    draw_set_transform(Vector2.ZERO)


## Outline points for the non-line kinds, already rotated about the centre.
func _rim(hw: float, hh: float, rot: float) -> PackedVector2Array:
    var c := Vector2.ZERO
    var pts := PackedVector2Array()
    var cr := cos(rot)
    var sr := sin(rot)
    var local: Array[Vector2] = []
    match shape_kind:
        Kind.CIRCLE:
            for i in ELLIPSE_SEGS:
                var a := TAU * float(i) / float(ELLIPSE_SEGS)
                local.append(Vector2(cos(a) * hw, sin(a) * hh))
        Kind.SQUARE:
            # side = h on BOTH axes; w is deliberately unused.
            local = [Vector2(-hh, -hh), Vector2(hh, -hh), Vector2(hh, hh), Vector2(-hh, hh)]
        Kind.RHOMBUS:
            local = [Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)]
        Kind.TRIANGLE:
            # isosceles pointing up: apex at -h/2, base w wide at +h/2
            local = [Vector2(0, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
        _:
            local = [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
    for p in local:
        pts.append(c + Vector2(p.x * cr - p.y * sr, p.x * sr + p.y * cr))
    return pts
