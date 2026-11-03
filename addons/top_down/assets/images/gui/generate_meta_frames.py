"""Paints the meta-upgrade screen art:

  meta_frame_normal_20x20_strip3.png   regular node frame, iron
  meta_frame_golden_28x28_strip3.png   keystone node frame, gold with studs and spikes
      both strips: frame 0 locked, 1 available, 2 owned
  meta_cursor_16x16.png                focus brackets, used as a 9-patch (margins 6)
  meta_icons_12x12_strip10.png         star, heart, sword, boot, dash, shield, coin, meat, slime, crystal
      (coin/meat/slime/crystal are frame 0 of the 8x8 item strips, centred)

Standard library only; rerun to regenerate (same pixels every run).
  python3 addons/top_down/assets/images/gui/generate_meta_frames.py [preview.png]
"""
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from generate_tile_variants import read_png, write_png  # noqa: E402

CLEAR = (0, 0, 0, 0)
OUTLINE = (24, 14, 30, 255)
WHITE = (255, 255, 255, 255)

# Per state: rim light (top-left), rim mid, rim shadow (bottom-right), inner edge, well outer, well centre.
NORMAL_STATES = [
	[(58, 56, 72, 255), (44, 42, 56, 255), (32, 30, 42, 255), (18, 12, 24, 255), (22, 16, 28, 255), (22, 16, 28, 255)],
	[(168, 172, 186, 255), (96, 100, 118, 255), (64, 66, 82, 255), OUTLINE, (40, 26, 52, 255), (40, 26, 52, 255)],
	[(214, 218, 228, 255), (150, 156, 170, 255), (92, 96, 112, 255), (255, 120, 220, 255), (70, 24, 80, 255), (140, 44, 136, 255)],
]
GOLDEN_STATES = [
	[(120, 92, 48, 255), (86, 62, 30, 255), (60, 42, 22, 255), (18, 12, 24, 255), (26, 18, 20, 255), (26, 18, 20, 255)],
	[(255, 236, 140, 255), (226, 176, 48, 255), (150, 98, 20, 255), OUTLINE, (48, 30, 30, 255), (48, 30, 30, 255)],
	[(255, 250, 210, 255), (255, 214, 90, 255), (200, 140, 40, 255), (255, 236, 140, 255), (84, 40, 16, 255), (150, 88, 28, 255)],
]
# Studs on the golden chamfers and the tips of its spikes, per state.
GOLDEN_STUD = [(150, 120, 70, 255), (255, 250, 220, 255), WHITE]


def blank(width, height):
	return [[CLEAR] * width for _ in range(height)]


def mix(a, b, t):
	return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def octagon_depth(x, y, size, chamfer, margin=0):
	"""Pixels in from the edge of a chamfered square (0 is the outermost ring), -1 outside."""
	lo, hi = margin, size - 1 - margin
	if x < lo or x > hi or y < lo or y > hi:
		return -1
	dx = min(x - lo, hi - x)
	dy = min(y - lo, hi - y)
	diagonal = dx + dy - chamfer
	if diagonal < 0:
		return -1
	return min(dx, dy, diagonal)


def paint_frame(size, chamfer, rim, colors, margin=0):
	"""Outline, a bevelled rim lit from the top-left, a dark inner edge and a radial well."""
	light, mid, shadow, edge, well_out, well_in = colors
	rows = blank(size, size)
	centre = (size - 1) / 2
	well_radius = centre - margin - rim - 1
	for y in range(size):
		for x in range(size):
			d = octagon_depth(x, y, size, chamfer, margin)
			if d < 0:
				continue
			if d == 0:
				rows[y][x] = OUTLINE
			elif d <= rim:
				lit = x + y < size - 1
				if d == 1:
					rows[y][x] = light if lit else shadow
				else:
					rows[y][x] = mid if lit or d < rim else shadow
			elif d == rim + 1:
				rows[y][x] = edge
			else:
				t = min(1.0, max(abs(x - centre), abs(y - centre)) / max(well_radius, 1))
				rows[y][x] = mix(well_in, well_out, t)
	return rows


def normal_frame(state):
	return paint_frame(20, 4, 2, NORMAL_STATES[state])


def golden_frame(state):
	size, margin = 28, 2
	rows = paint_frame(size, 7, 3, GOLDEN_STATES[state], margin)
	light, mid, shadow = GOLDEN_STATES[state][:3]
	stud = GOLDEN_STUD[state]
	# Spikes: a wedge out of the middle of each edge, its tip in the margin, its base
	# breaking through the outline into the rim.
	mid_lo, mid_hi = size // 2 - 1, size // 2
	wedge = [  # (depth from the outside, along-edge pixels -> color)
		(0, {mid_lo: OUTLINE, mid_hi: OUTLINE}),
		(1, {mid_lo - 1: OUTLINE, mid_lo: stud, mid_hi: light, mid_hi + 1: OUTLINE}),
		(2, {mid_lo - 1: OUTLINE, mid_lo: light, mid_hi: mid, mid_hi + 1: OUTLINE}),
	]
	for depth, pixels in wedge:
		for i, color in pixels.items():
			rows[depth][i] = color
			rows[size - 1 - depth][size - 1 - i] = color
			rows[size - 1 - i][depth] = color
			rows[i][size - 1 - depth] = color
	# Studs: a lit 2x2 on each chamfer of the rim.
	for sx, sy in ((7, 7), (size - 9, 7), (7, size - 9), (size - 9, size - 9)):
		for oy in (0, 1):
			for ox in (0, 1):
				rows[sy + oy][sx + ox] = stud if (ox, oy) == (0, 0) else light if ox + oy == 1 else shadow
	return rows


def cursor():
	"""Corner brackets, white with an outline; the middle stays clear so it stretches as a 9-patch."""
	size, arm = 16, 5
	rows = blank(size, size)
	for corner_x, corner_y in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
		sx = 1 if corner_x == 0 else -1
		sy = 1 if corner_y == 0 else -1
		for i in range(arm + 1):
			for along_x, along_y in ((corner_x + sx * i, corner_y), (corner_x, corner_y + sy * i)):
				rows[along_y][along_x] = OUTLINE
		for i in range(1, arm):
			rows[corner_y + sy][corner_x + sx * i] = WHITE
			rows[corner_y + sy * i][corner_x + sx] = WHITE
		for i in range(2, arm):
			rows[corner_y + sy * 2][corner_x + sx * i] = OUTLINE
			rows[corner_y + sy * i][corner_x + sx * 2] = OUTLINE
		rows[corner_y + sy * 2][corner_x + sx * 2] = OUTLINE
		rows[corner_y + sy * arm][corner_x + sx] = OUTLINE
		rows[corner_y + sy][corner_x + sx * arm] = OUTLINE
	return rows


ICON_COLORS = {
	'Y': (250, 204, 72, 255), 'y': (180, 130, 40, 255),
	'R': (214, 52, 64, 255), 'r': (150, 30, 44, 255),
	'S': (168, 172, 186, 255), 's': (96, 100, 118, 255),
	'H': (226, 176, 48, 255), 'h': (128, 80, 44, 255),
	'B': (150, 96, 54, 255), 'b': (96, 58, 34, 255),
	'A': (90, 220, 210, 255), 'a': (40, 140, 150, 255),
	'C': (196, 64, 176, 255),
	'w': (255, 244, 230, 255),
}
# 10x10 shapes; the outline is added around them.
ICON_SHAPES = {
	'star': [
		'....YY....',
		'...YwYY...',
		'...YwYY...',
		'YYYYYYYYYY',
		'.YYYYYYYy.',
		'..YYYYYy..',
		'..YYYYYy..',
		'.YYYyyYYy.',
		'.YYy..yYy.',
		'.Yy....yy.',
	],
	'heart': [
		'..........',
		'.RR....RR.',
		'RwRR..RRRR',
		'RwRRRRRRRR',
		'RRRRRRRRRr',
		'RRRRRRRRRr',
		'.RRRRRRRr.',
		'..RRRRRr..',
		'...RRRr...',
		'....Rr....',
	],
	'sword': [
		'........wS',
		'.......wSS',
		'......wSS.',
		'.....wSS..',
		'....wSS...',
		'.H.wSS....',
		'..HSs.....',
		'..hH......',
		'.hh.H.....',
		'hh........',
	],
	'boot': [
		'...BBBB...',
		'...BBBb...',
		'...BBBb...',
		'w..BBBb...',
		'.w.BBBb...',
		'w..BBBBB..',
		'...BBBBBBb',
		'..BBBBBBBb',
		'..bbbbbbbb',
		'..........',
	],
	'dash': [
		'A....A....',
		'AA...AA...',
		'.AA...AA..',
		'..AA...AA.',
		'...AA...AA',
		'...aa...aa',
		'..aa...aa.',
		'.aa...aa..',
		'aa...aa...',
		'a....a....',
	],
	'shield': [
		'ssssssssss',
		'sSSSSSSSSs',
		'sSCCCCCCSs',
		'sSCwCCCCSs',
		'sSCCCCCCSs',
		'.sSCCCCSs.',
		'.sSCCCCSs.',
		'..sSCCSs..',
		'...sSSs...',
		'....ss....',
	],
}
ITEM_ICONS = {
	'coin': 'items/coin_8x8_strip3.png',
	'meat': 'items/meat_8x8_strip3.png',
	'slime': 'items/slime_ball_8x8_strip3.png',
	'crystal': 'items/boss_crystal_8x8_strip3.png',
}
## Order of the icon strip; MetaUpgrades.ICONS in game/scripts/meta/MetaUpgrades.gd must match.
ICON_ORDER = ['star', 'heart', 'sword', 'boot', 'dash', 'shield', 'coin', 'meat', 'slime', 'crystal']


def add_outline(rows):
	height, width = len(rows), len(rows[0])
	out = [row[:] for row in rows]
	for y in range(height):
		for x in range(width):
			if rows[y][x][3]:
				continue
			for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
				if 0 <= nx < width and 0 <= ny < height and rows[ny][nx][3] and rows[ny][nx] != OUTLINE:
					out[y][x] = OUTLINE
					break
	return out


def icon(name):
	rows = blank(12, 12)
	if name in ITEM_ICONS:
		item = read_png(os.path.join(os.path.dirname(HERE), ITEM_ICONS[name]))
		for y in range(8):
			for x in range(8):
				rows[y + 2][x + 2] = item[y][x]
		return rows
	shape = ICON_SHAPES[name]
	assert len(shape) == 10 and all(len(r) == 10 for r in shape), name
	for y, text in enumerate(shape):
		for x, key in enumerate(text):
			if key != '.':
				rows[y + 1][x + 1] = ICON_COLORS[key]
	return add_outline(rows)


def strip(frames):
	return [sum((frame[y] for frame in frames), []) for y in range(len(frames[0]))]


def main():
	write_png(os.path.join(HERE, 'meta_frame_normal_20x20_strip3.png'), strip([normal_frame(s) for s in range(3)]))
	write_png(os.path.join(HERE, 'meta_frame_golden_28x28_strip3.png'), strip([golden_frame(s) for s in range(3)]))
	write_png(os.path.join(HERE, 'meta_cursor_16x16.png'), cursor())
	write_png(os.path.join(HERE, 'meta_icons_12x12_strip%d.png' % len(ICON_ORDER)), strip([icon(n) for n in ICON_ORDER]))


def preview(path, scale=6):
	"""Upscaled sheet: each frame state with an icon on top, then the cursor and the icon strip."""
	background = (40, 52, 50, 255)
	sheet = []

	def compose(frame, icon_rows):
		size = len(frame)
		out = [row[:] for row in frame]
		offset = (size - 12) // 2
		for y in range(12):
			for x in range(12):
				if icon_rows[y][x][3]:
					out[y + offset][x + offset] = icon_rows[y][x]
		return out

	heart, star = icon('heart'), icon('star')
	rows_sets = [
		strip([compose(normal_frame(s), heart) for s in range(3)] + [normal_frame(s) for s in range(3)]),
		strip([compose(golden_frame(s), star) for s in range(3)] + [golden_frame(s) for s in range(3)]),
		cursor(),
		strip([icon(n) for n in ICON_ORDER]),
	]
	width = max(len(r[0]) for r in rows_sets) * scale
	for rows in rows_sets:
		for row in rows:
			line = []
			for pixel in row:
				line.extend([pixel if pixel[3] else background] * scale)
			line.extend([(24, 24, 24, 255)] * (width - len(line)))
			sheet.extend([line] * scale)
		sheet.extend([[(24, 24, 24, 255)] * width] * scale)
	write_png(path, sheet)


if __name__ == '__main__':
	main()
	if len(sys.argv) > 1:
		preview(sys.argv[1])
