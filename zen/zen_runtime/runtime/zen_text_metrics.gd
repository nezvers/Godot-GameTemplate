@tool
extends RefCounted
##
## Text layout against a real Godot font, replacing the raylib bitmap-font
## emulation this used to reproduce exactly (see docs/plans/godot-integration.md
## Task 2 - the old WIDTHS table and text_ref.txt comparison are gone).
##
## Two traps this exists to not re-fall into:
##   - Font.get_string_size() IGNORES "\n" (measured on 4.7.2: "two\nlines" at
##     size 72 -> (293, 99), one line's worth of height). So height is
##     computed from the LAYOUT, not the font: box.y = size_px * lines +
##     LINE_SPACING * (lines - 1). This also means the box stays a layout
##     rule, not a font metric - swapping fonts does not move the text, only
##     changes its letterforms, which is the whole point of making the font a
##     choice.
##   - A fixed-size bitmap font reports a flat ascent == size; a real font's
##     ascent+descent (e.g. 77+22 at size 72) is bigger than size_px, so the
##     text BLOCK's height must come from the layout rule above, while each
##     LINE's own baseline (in zen_text.gd) is placed proportionally inside
##     that line's slot, not by summing the font's own metrics.
##

const BASE_SIZE := 10
## Vertical gap between wrapped lines, in px. Matches raylib's old default.
const LINE_SPACING := 2.0


## Zen's spacing rule: TextSpacingFor(sizePx) = sizePx / baseSize (anim.c:1127).
## No longer used for LAYOUT (native kerning owns inter-glyph spacing now) -
## kept because crumble still needs a per-glyph advance between scattered
## letters.
static func spacing_for(size_px: float) -> float:
	return size_px / float(BASE_SIZE)


## A fixed-size bitmap font - the raylib default (tools/gen_raylib_font.gd).
## It scales its atlas, so it wants nearest sampling and raylib's spacing rule.
static func is_bitmap(f: Font) -> bool:
	return f is FontFile and (f as FontFile).fixed_size > 0


## The integer font size text is LAID OUT at; drawing then scales it by
## size_px / ref_size with a float transform. Laying out at round(size_px)
## instead made an animated size step a whole pixel at a time - each step
## re-centred the block and re-rounded every pen position, so text that grew
## while moving stuttered against its own smooth position. A bitmap font lays
## out at its native size, exactly as raylib's DrawTextEx scaled its atlas; a
## vector font at the next power of two up, so it only ever shrinks (stays
## sharp) and its layout changes only when the size crosses a power of two.
static func ref_size(size_px: float, font: Font) -> int:
	if is_bitmap(font): return (font as FontFile).fixed_size
	return maxi(16, nearest_po2(int(ceil(size_px))))


## The text block's size at `size_px` against `font`. Empty text measures
## {0,0} - not a degenerate run of the per-line loop, which would still give a
## correct {0,0} but needlessly asks the font for an empty string's size.
static func measure(text: String, size_px: float, font: Font) -> Vector2:
	if text.is_empty(): return Vector2.ZERO
	var lines := text.split("\n")
	var ref := ref_size(size_px, font)
	var w := 0.0
	# A bitmap font's advance carries raylib's one-base-pixel spacing after
	# EVERY glyph; MeasureTextEx counts it only BETWEEN glyphs, so drop the
	# trailing one to centre exactly where the original editor did.
	var trail := float(ref) / float(font.fixed_size) if is_bitmap(font) else 0.0
	for line in lines:
		if line.is_empty(): continue
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, ref).x - trail)
	var h := size_px * lines.size() + LINE_SPACING * (lines.size() - 1)
	return Vector2(w * size_px / float(ref), h)
