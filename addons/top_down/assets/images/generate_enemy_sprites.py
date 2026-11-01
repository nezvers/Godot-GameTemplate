#!/usr/bin/env python3
"""Pixel-art generator for the new zombie, slime, spider and boss sprites.

Pure standard library (zlib + struct), so no image package is needed.
Run it from anywhere; it writes the PNG files next to this script:

    python3 generate_enemy_sprites.py

Output layout:
- characters/*_16x16_strip8.png  8-frame strips, same format as the existing sheets
- characters/*_64x64.png         single-frame bosses, same format as big_jelly_64x64.png
- projectile/*_8x8.png           single-frame projectiles
"""
import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))

FRAME_COUNT = 8
## Rows from this index down are legs; they swing sideways while walking.
LEG_ROW = 12

PALETTE = {
	'g': (123, 179, 79, 255),   # zombie green
	'l': (166, 214, 107, 255),  # light green
	'd': (74, 122, 51, 255),    # dark green
	'p': (126, 90, 168, 255),   # bloat purple
	'P': (176, 143, 214, 255),  # light purple
	'y': (200, 214, 74, 255),   # sickly yellow
	'r': (107, 74, 46, 255),    # rags
	'b': (58, 40, 24, 255),     # dark brown
	'a': (67, 214, 166, 255),   # acid teal
	'A': (166, 255, 216, 255),  # acid highlight
	't': (24, 110, 96, 255),    # acid rim
	'x': (42, 36, 48, 255),     # spider black
	'X': (77, 69, 88, 255),     # spider grey
	'Y': (128, 118, 146, 255),   # spider leg grey
	'w': (232, 226, 200, 255),  # bone white
	'e': (223, 233, 240, 255),  # web white
	'R': (224, 48, 46, 255),    # red eyes
	'k': (27, 20, 32, 255),     # black
	'S': (96, 150, 220, 255),   # slime puddle blue
	's': (56, 92, 150, 255),    # slime puddle rim
	'L': (190, 220, 250, 255),  # slime puddle highlight
	'm': (128, 28, 44, 255),    # dark crimson
	'q': (134, 148, 98, 255),   # plague skin
	'Q': (172, 186, 126, 255),  # plague skin light
	'z': (90, 100, 66, 255),    # plague skin dark
	'B': (38, 26, 18, 255),     # deep rags shadow
	'v': (78, 52, 108, 255),    # shawl purple dark
	'o': (112, 138, 92, 255),   # rotting skin
	'O': (146, 168, 116, 255),  # rotting skin light
	'n': (68, 88, 60, 255),     # rotting skin dark
	'W': (184, 172, 140, 255),  # bone shadow
	'h': (232, 182, 140, 255),  # skin
	'H': (184, 124, 96, 255),   # skin shadow
	'i': (255, 244, 160, 255),  # impact yellow
}
OUTLINE = (20, 14, 26, 255)
TRANSPARENT = (0, 0, 0, 0)


def new_canvas(width, height):
	return [[None] * width for _ in range(height)]


def put(canvas, x, y, color):
	x = round(x)
	y = round(y)
	if 0 <= y < len(canvas) and 0 <= x < len(canvas[0]):
		canvas[y][x] = color


def ellipse(canvas, cx, cy, rx, ry, color):
	for y in range(len(canvas)):
		for x in range(len(canvas[0])):
			dx = (x + 0.5 - cx) / rx
			dy = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				canvas[y][x] = color


def thick_line(canvas, x0, y0, x1, y1, thickness, color):
	radius = thickness / 2.0
	length_sq = max((x1 - x0) ** 2 + (y1 - y0) ** 2, 1e-9)
	for y in range(len(canvas)):
		for x in range(len(canvas[0])):
			px = x + 0.5
			py = y + 0.5
			t = max(0.0, min(1.0, ((px - x0) * (x1 - x0) + (py - y0) * (y1 - y0)) / length_sq))
			nearest_x = x0 + t * (x1 - x0)
			nearest_y = y0 + t * (y1 - y0)
			if (px - nearest_x) ** 2 + (py - nearest_y) ** 2 <= radius * radius:
				canvas[y][x] = color


def add_outline(canvas):
	"""Adds a 1px dark outline around the silhouette."""
	height = len(canvas)
	width = len(canvas[0])
	result = [row[:] for row in canvas]
	for y in range(height):
		for x in range(width):
			if canvas[y][x] is not None:
				continue
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx = x + dx
				ny = y + dy
				if 0 <= nx < width and 0 <= ny < height and canvas[ny][nx] is not None:
					result[y][x] = OUTLINE
					break
	return result


def from_rows(rows):
	"""Builds a 16x16 canvas from palette-key rows, each centred horizontally. '.' is transparent."""
	assert len(rows) == 16, 'expected 16 rows, got %d' % len(rows)
	canvas = new_canvas(16, 16)
	for y, text in enumerate(rows):
		assert len(text) <= 16, text
		left = (16 - len(text)) // 2
		for i, key in enumerate(text):
			if key != '.':
				canvas[y][left + i] = PALETTE[key]
	return canvas


def walk_frames(base):
	"""Eight frames: whole body bobs, legs swing left and right."""
	frames = []
	for frame in range(FRAME_COUNT):
		bob = -1 if frame in (2, 6) else 0
		swing = (0, 1, 0, -1)[frame % 4]
		canvas = new_canvas(16, 16)
		for y in range(16):
			for x in range(16):
				color = base[y][x]
				if color is None:
					continue
				new_x = x
				if y >= LEG_ROW:
					new_x = x + swing if x < 8 else x - swing
				put(canvas, new_x, y + bob, color)
		frames.append(add_outline(canvas))
	return frames


## Left-side legs as (anchor, knee, foot) in 16x16 pixel space, top-down.
## Group 'A' and 'B' take turns lifting during the walk; the right side mirrors them.
SPIDER_LEGS = [
	((5.0, 4.5), (3.0, 2.0), (2.0, 0.5), 'A'),
	((5.0, 6.5), (2.5, 6.0), (1.0, 5.0), 'B'),
	((5.0, 8.5), (2.5, 9.5), (1.0, 10.5), 'A'),
	((5.0, 10.5), (3.0, 13.0), (2.0, 14.5), 'B'),
]


def spider_frames(body, abdomen, leg_color, eye_color, fang_color, marks=None):
	"""Top-down spider: head and fangs up top, round abdomen below, legs alternate groups while walking.
	Frame 0 is used as the dead spider lying on its back."""
	frames = []
	for frame in range(FRAME_COUNT):
		step = math.sin(frame / FRAME_COUNT * 2 * math.pi)
		canvas = new_canvas(16, 16)
		for side in (0, 1):
			for anchor, knee, foot, group in SPIDER_LEGS:
				lift = step if group == 'A' else -step
				points = [anchor, (knee[0], knee[1] + 0.8 * lift), (foot[0], foot[1] + 1.0 * lift)]
				if side == 1:
					points = [(16.0 - x, y) for x, y in points]
				thick_line(canvas, points[0][0], points[0][1], points[1][0], points[1][1], 1.0, leg_color)
				thick_line(canvas, points[1][0], points[1][1], points[2][0], points[2][1], 1.0, leg_color)
		bob = 0.4 * step
		ellipse(canvas, 7.5, 11.0 + bob, 3.2, 3.0, abdomen)
		ellipse(canvas, 7.5, 5.0 + bob, 2.4, 2.2, body)
		if marks is not None:
			for x, y in ((7, 10), (8, 10), (7, 12), (8, 12)):
				put(canvas, x, y + round(bob), marks)
		put(canvas, 6, 3, eye_color)
		put(canvas, 9, 3, eye_color)
		put(canvas, 7, 4, fang_color)
		put(canvas, 8, 4, fang_color)
		frames.append(add_outline(canvas))
	return frames


## Near side legs front to back as (anchor x, foot x, knee height above the ground), side view facing right.
## Outer legs arch higher; far side legs are drawn from the same list, reaching less.
CRAWL_LEGS = [(10.0, 15.0, 10.0), (9.5, 12.5, 9.0), (8.5, 3.5, 10.0), (8.0, 0.5, 11.0)]
CRAWL_GROUND = 15


def line_pixels(x0, y0, x1, y1):
	"""1px Bresenham line between rounded points, so legs stay thin and readable at 16x16."""
	x0, y0, x1, y1 = round(x0), round(y0), round(x1), round(y1)
	points = set()
	dx = abs(x1 - x0)
	dy = -abs(y1 - y0)
	sx = 1 if x0 < x1 else -1
	sy = 1 if y0 < y1 else -1
	error = dx + dy
	while True:
		points.add((x0, y0))
		if x0 == x1 and y0 == y1:
			return points
		e2 = 2 * error
		if e2 >= dy:
			error += dy
			x0 += sx
		if e2 <= dx:
			error += dx
			y0 += sy


def spider_crawl_pose(t, moving, body, abdomen, leg_color, far_color, eye_color, fang_color, marks):
	"""Side view spider, facing right. t is the 0..1 gait phase; legs step in two alternating groups of four."""
	# whole pixel body lift halfway through each step keeps the shapes clean
	lift_body = -1 if moving and math.sin(4 * math.pi * t) > 0.5 else 0
	if not moving and t >= 0.5:
		lift_body = -1

	def leg(index, near):
		anchor_x, foot_x, knee_height = CRAWL_LEGS[index]
		phase = t + (0.0 if (index % 2 == 0) == near else 0.5)
		# lifted foot swings forward, planted foot pushes back
		swing = 1.5 * math.sin(2 * math.pi * phase) if moving else 0.0
		lift = 1.5 * max(0.0, math.cos(2 * math.pi * phase)) if moving else 0.0
		outward = 1 if foot_x > anchor_x else -1
		if not near:
			foot_x -= 1.5 * outward
			knee_height -= 1.0
		foot = (foot_x + swing, CRAWL_GROUND - lift)
		anchor = (anchor_x, 11 + lift_body)
		knee = (anchor_x + (0.35 if outward > 0 else 0.6) * (foot[0] - anchor_x), CRAWL_GROUND - knee_height + lift_body - 0.5 * lift)
		return line_pixels(*anchor, *knee) | line_pixels(*knee, *foot)

	body_canvas = new_canvas(16, 16)
	ellipse(body_canvas, 5.0, 10.5 + lift_body, 3.8, 2.9, abdomen)
	if marks is not None:
		put(body_canvas, 3, 9 + lift_body, marks)
		put(body_canvas, 4, 9 + lift_body, marks)
		put(body_canvas, 3, 10 + lift_body, marks)
	ellipse(body_canvas, 10.5, 11.5 + lift_body, 2.4, 1.8, body)
	put(body_canvas, 11, 11 + lift_body, eye_color)
	put(body_canvas, 12, 11 + lift_body, eye_color)
	put(body_canvas, 12, 13 + lift_body, fang_color)
	body_canvas = add_outline(body_canvas)
	# legs arch over the body and reach the ground below it; the body covers their roots
	canvas = new_canvas(16, 16)
	for near, color in ((False, far_color), (True, leg_color)):
		for i in range(4):
			for x, y in leg(i, near):
				put(canvas, x, y, color)
	for y in range(16):
		for x in range(16):
			if body_canvas[y][x] is not None:
				canvas[y][x] = body_canvas[y][x]
	return canvas


def spider_crawl_frames(body, abdomen, leg_color, far_color, eye_color, fang_color, marks=None):
	"""Frames 0-1 idle (breathing), 2-7 one crawl cycle; same idle/walk layout as the other strips."""
	frames = [spider_crawl_pose(i / 2, False, body, abdomen, leg_color, far_color, eye_color, fang_color, marks) for i in range(2)]
	frames += [spider_crawl_pose(i / 6, True, body, abdomen, leg_color, far_color, eye_color, fang_color, marks) for i in range(6)]
	return frames


def acid_spit_projectile():
	canvas = new_canvas(8, 8)
	ellipse(canvas, 4, 4, 3.2, 3.2, PALETTE['a'])
	ellipse(canvas, 3, 3, 1.0, 1.0, PALETTE['A'])
	return add_outline(canvas)


def web_projectile():
	canvas = new_canvas(8, 8)
	ellipse(canvas, 4, 4, 3.0, 3.0, PALETTE['e'])
	thick_line(canvas, 1, 4, 7, 4, 0.7, PALETTE['w'])
	thick_line(canvas, 4, 1, 4, 7, 0.7, PALETTE['w'])
	return add_outline(canvas)


## Bandaged fist pointing right, held the same way as gun_0.png: forearm wraps on the left, knuckles on the right.
FIST_MAP = [
	'', '', '', '', '', '',
	'........hhh.....',
	'....WwWhhhhH....',
	'....WwWhHHhH....',
	'....WwWhhhHH....',
	'........HHH.....',
	'', '', '', '', '',
]


def fist_sprite():
	return add_outline(from_rows(FIST_MAP))


def punch_frames():
	"""Four 16x16 frames of a punch impact travelling right: a small flash, a burst with speed lines
	trailing behind it, the burst breaking into sparks, last sparks fading."""
	frames = []
	for frame in range(4):
		canvas = new_canvas(16, 16)
		radius = (2.0, 4.5, 5.5, 6.0)[frame]
		# speed lines trail behind the knuckles
		if frame < 3:
			for y, length in ((5, 4), (8, 6), (11, 4)):
				thick_line(canvas, 6 - length - frame, y, 6 - frame, y, 1.0, PALETTE['e'])
		# star burst: long rays on the axes, short ones on the diagonals
		for angle in range(0, 360, 45):
			radians = math.radians(angle + 22.5 * (frame % 2))
			reach = radius * (1.0 if angle % 90 == 0 else 0.65)
			start = 0.0 if frame < 2 else radius * 0.6
			thick_line(canvas, 10 + start * math.cos(radians), 8 + start * math.sin(radians),
				10 + reach * math.cos(radians), 8 + reach * math.sin(radians), 1.2, PALETTE['i'])
		if frame < 2:
			ellipse(canvas, 10, 8, radius * 0.5, radius * 0.5, PALETTE['w'])
		if frame == 3:
			# only scattered sparks left
			canvas = [[c if (x + y) % 3 == 0 else None for x, c in enumerate(row)] for y, row in enumerate(canvas)]
		frames.append(canvas)
	return frames


def rotate_cw(canvas):
	"""Rotates a square canvas 90 degrees clockwise, so a figure facing right falls forward onto its face."""
	size = len(canvas)
	return [[canvas[size - 1 - x][y] for x in range(size)] for y in range(size)]


def flip_vertical(canvas):
	return [row[:] for row in reversed(canvas)]


def drop_to_ground(canvas, ground):
	"""Moves the drawing down so its lowest pixel sits on the ground row."""
	lowest = max(y for y, row in enumerate(canvas) if any(c is not None for c in row))
	shift = ground - lowest
	result = new_canvas(len(canvas[0]), len(canvas))
	for y, row in enumerate(canvas):
		if 0 <= y + shift < len(canvas):
			result[y + shift] = row[:]
	return result


def under(pool, canvas):
	"""Draws canvas over pool; used to put a corpse in its puddle."""
	return [[c if c is not None else p for c, p in zip(row, pool_row)] for row, pool_row in zip(canvas, pool)]


def pool_canvas(width, height, cx, cy, rx, ry, rim, fill, drops):
	pool = new_canvas(width, height)
	ellipse(pool, cx, cy, rx, ry, rim)
	ellipse(pool, cx, cy, rx - 1.5, ry - 1.0, fill)
	for x, y, r in drops:
		ellipse(pool, x, y, r, r * 0.7, fill)
	return pool


def bloater_dead_frame():
	"""Burst bloater lying in its own green muck: flattened body, belly torn open, X eyes."""
	body = new_canvas(16, 16)
	ellipse(body, 8, 10.5, 5.5, 2.6, PALETTE['g'])
	ellipse(body, 8.5, 10, 3.2, 1.6, PALETTE['p'])
	ellipse(body, 9, 10, 2.0, 1.0, PALETTE['m'])
	put(body, 9, 10, PALETTE['k'])
	# torn skin flaps curling up out of the burst
	for x, y in ((6, 8), (10, 8), (12, 9)):
		put(body, x, y, PALETTE['P'])
	put(body, 5, 11, PALETTE['r'])
	put(body, 4, 11, PALETTE['r'])
	# head on the left with crossed out eyes
	ellipse(body, 3.5, 9.5, 2.0, 1.8, PALETTE['g'])
	put(body, 3, 9, PALETTE['k'])
	put(body, 4, 10, PALETTE['k'])
	pool = pool_canvas(16, 16, 8, 11.5, 7.5, 3.2, PALETTE['d'], PALETTE['y'], ((2, 14, 1.0), (14, 13, 0.8)))
	return under(pool, add_outline(body))


def acid_slime_dead_frame():
	"""Acid slime splattered flat: a teal splash with droplets thrown out, two dead eyes floating in it.
	No outline, it lies on the floor like the puddles."""
	canvas = pool_canvas(16, 16, 8, 10, 6.5, 2.8, PALETTE['t'], PALETTE['a'],
		((1.5, 8, 0.9), (14.5, 9, 0.9), (3, 14, 0.8), (13, 13.5, 1.0), (9, 6.5, 0.7), (5, 6.5, 0.6)))
	# lumps of the body that didn't melt yet
	ellipse(canvas, 10, 10, 2.0, 1.2, PALETTE['t'])
	put(canvas, 5, 9, PALETTE['A'])
	put(canvas, 6, 9, PALETTE['A'])
	put(canvas, 12, 11, PALETTE['A'])
	put(canvas, 6, 11, PALETTE['k'])
	put(canvas, 10, 10, PALETTE['k'])
	return canvas


def giant_zombie_dead_frame():
	"""The brute fallen forward onto its face in a pool of blood, jaw hanging, eye gone dark."""
	figure = giant_zombie_pose(jaw=1.0, lean=0.3, dead=True)
	figure = drop_to_ground(rotate_cw(figure), 58)
	pool = pool_canvas(64, 64, 34, 56, 28, 6, PALETTE['m'], PALETTE['R'], ((6, 60, 2.0), (60, 59, 1.6)))
	return under(pool, figure)


def broodmother_dead_frame():
	"""Spider on her back with legs curled up over the belly, lying in dark ichor."""
	figure = broodmother_pose(curl=1.0, dead=True)
	figure = drop_to_ground(flip_vertical(figure), 58)
	pool = pool_canvas(64, 64, 30, 56, 26, 6, PALETTE['k'], PALETTE['v'], ((4, 60, 1.6), (58, 59, 1.4)))
	return under(pool, figure)


def plague_mother_dead_frame():
	"""Collapsed onto her face, acid sacs burst and empty, leaking into an acid pool."""
	figure = plague_mother_pose(swell=-1.6, hunch=1.0, mouth=1.0, dead=True)
	figure = drop_to_ground(rotate_cw(figure), 58)
	pool = pool_canvas(64, 64, 32, 56, 28, 6, PALETTE['t'], PALETTE['a'], ((5, 60, 2.0), (60, 59, 1.6)))
	ellipse(pool, 20, 55, 3, 1.2, PALETTE['A'])
	return under(pool, figure)


def giant_zombie_pose(t=0.0, moving=False, near_fist=None, far_fist=None, jaw=0.0, head_back=0.0, lean=0.0, bob=0, dead=False):
	"""64x64 hulking zombie brute facing right: bone spikes through the hunched back, ribs showing
	through a torn belly, a stitched shoulder and a broken forearm bone.
	near_fist / far_fist place the fists (None lets them hang by the knees), jaw opens the hanging jaw,
	head_back throws the head up (roar), lean pushes the upper body forward, bob lifts it in pixels."""
	stride = math.sin(2 * math.pi * t) if moving else 0.0
	up = bob + round(2 * lean)
	shift = round(4 * lean)
	shoulder_near = (40.0 + shift, 26.0 + up)
	shoulder_far = (30.0 + shift, 24.0 + up)
	if near_fist is None:
		near_fist = (50.0 + shift + 3 * stride, 50.0 + up)
	if far_fist is None:
		far_fist = (40.0 + shift - 3 * stride, 48.0 + up)
	head_x = 47 + shift - round(3 * head_back)
	head_y = 23 + up - round(6 * head_back)

	back = new_canvas(64, 64)
	# far leg and arm in shadow
	jointed_limb(back, [(32, 44 + up), (36 - 4 * stride, 53 + up), (35 - 6 * stride, 61)], 8, PALETTE['n'])
	jointed_limb(back, [shoulder_far, ((shoulder_far[0] + far_fist[0]) / 2 - 2, (shoulder_far[1] + far_fist[1]) / 2 + 2), far_fist], 7, PALETTE['n'])
	ellipse(back, far_fist[0], far_fist[1], 5, 4.5, PALETTE['n'])

	body = new_canvas(64, 64)
	jointed_limb(body, [(24, 44 + up), (25 + 4 * stride, 53 + up), (23 + 6 * stride, 61)], 9, PALETTE['o'])
	thick_line(body, 19 + 6 * stride, 61, 29 + 6 * stride, 61, 3, PALETTE['n'])
	# torn trousers
	shaded_ellipse(body, 28, 46 + up, 13, 6, PALETTE['r'], PALETTE['r'], PALETTE['b'])
	for x in (18, 23, 30, 36):
		thick_line(body, x, 50 + up, x + 1, 54 + up, 2, PALETTE['b'])
	# tapered bone spikes breaking out of the spine, bloody where they tear through
	for (x0, y0), (x1, y1) in (((15, 27), (6, 17)), ((21, 20), (14, 7)), ((29, 16), (26, 2))):
		for step in range(6):
			k = step / 5
			thick_line(body, x0 + shift + (x1 - x0) * k * 0.8, y0 + up + (y1 - y0) * k * 0.8,
				x0 + shift + (x1 - x0) * min(1.0, k + 0.25), y0 + up + (y1 - y0) * min(1.0, k + 0.25),
				4.2 - 3.2 * k, PALETTE['W'] if step < 2 else PALETTE['w'])
		ellipse(body, x0 + shift, y0 + up, 3, 2.4, PALETTE['m'])
	# hunched torso and gut
	shaded_ellipse(body, 28 + shift, 31 + up, 18, 15, PALETTE['o'], PALETTE['O'], PALETTE['n'])
	shaded_ellipse(body, 34 + shift, 39 + up, 12, 8, PALETTE['o'], PALETTE['O'], PALETTE['n'])
	# torn open belly: ragged raw edge, dark cavity, ribs showing through
	for x, y, rx, ry in ((36, 35, 6.5, 7.5), (32, 32, 3.0, 3.0), (40, 40, 3.5, 3.0), (35, 41, 3.5, 2.5)):
		ellipse(body, x + shift, y + up, rx, ry, PALETTE['m'])
	ellipse(body, 37 + shift, 36 + up, 4.2, 5.2, PALETTE['k'])
	for y, x0, x1 in ((32, 34, 39), (35, 33, 40), (38, 34, 40)):
		thick_line(body, x0 + shift, y + up, x1 + shift, y + 1.5 + up, 1.1, PALETTE['W'])
		put(body, x1 + shift, y + 1 + up, PALETTE['w'])
	# bruised, rotting patches
	for x, y, r in ((23, 40, 3.0), (31, 22, 2.2)):
		ellipse(body, x + shift, y + up, r, r * 0.8, PALETTE['n'])
		put(body, x + shift, y + up, PALETTE['v'])
	jointed_limb(body, [(37 + shift, 41 + up), (39 + shift + stride, 46 + up), (37 + shift + 2 * stride, 50 + up)], 2, PALETTE['R'])
	# blood smears and a stitched gash on the back
	for x, y in ((20, 36), (23, 40), (18, 31)):
		ellipse(body, x + shift, y + up, 1.6, 1.2, PALETTE['m'])
	thick_line(body, 15 + shift, 31 + up, 27 + shift, 25 + up, 1, PALETTE['m'])
	for i in range(4):
		x = 17 + shift + i * 3
		y = 30 + up - i * 1.5
		thick_line(body, x - 0.5, y - 1.5, x + 0.5, y + 1.5, 1, PALETTE['k'])

	head = new_canvas(64, 64)
	shaded_ellipse(head, head_x, head_y, 7, 6.5, PALETTE['o'], PALETTE['O'], PALETTE['n'])
	# hanging lower jaw with broken teeth
	jaw_drop = 2 + 5 * jaw
	shaded_ellipse(head, head_x + 2, head_y + 4 + jaw_drop, 5, 2.5, PALETTE['n'], PALETTE['o'], PALETTE['n'])
	ellipse(head, head_x + 3, head_y + 3 + jaw_drop / 2, 3.5, jaw_drop / 2 + 0.5, PALETTE['k'])
	for x in (head_x + 1, head_x + 3, head_x + 5):
		put(head, x, head_y + 2, PALETTE['w'])
		put(head, x, head_y + 2 + jaw_drop, PALETTE['w'])
	thick_line(head, head_x + 4, head_y + 5 + jaw_drop, head_x + 4, head_y + 8 + jaw_drop, 1.2, PALETTE['R'])
	# one glowing eye, one gouged socket bleeding
	ellipse(head, head_x + 4, head_y - 2, 1.4, 1.4, PALETTE['k'] if dead else PALETTE['R'])
	put(head, head_x + 4, head_y - 2, PALETTE['W'] if dead else PALETTE['y'])
	ellipse(head, head_x, head_y - 2, 1.5, 1.5, PALETTE['k'])
	thick_line(head, head_x, head_y - 1, head_x - 1, head_y + 3, 1, PALETTE['m'])
	# scalp torn back to bone
	ellipse(head, head_x - 2, head_y - 5, 3, 1.6, PALETTE['w'])

	front = new_canvas(64, 64)
	elbow = ((shoulder_near[0] + near_fist[0]) / 2 + 3, (shoulder_near[1] + near_fist[1]) / 2 + 1)
	jointed_limb(front, [shoulder_near, elbow, near_fist], 8, PALETTE['o'])
	# broken bone sticking out of the forearm
	mid = ((elbow[0] + near_fist[0]) / 2, (elbow[1] + near_fist[1]) / 2)
	thick_line(front, mid[0], mid[1], mid[0] + 4, mid[1] - 3, 2, PALETTE['w'])
	ellipse(front, mid[0], mid[1], 1.6, 1.6, PALETTE['m'])
	# stitches around the shoulder where the arm was sewn back on
	for i in range(4):
		angle = math.radians(200 + i * 40)
		x = shoulder_near[0] + 4.5 * math.cos(angle)
		y = shoulder_near[1] + 4.5 * math.sin(angle)
		thick_line(front, x - 1, y - 1, x + 1, y + 1, 1, PALETTE['k'])
	shaded_ellipse(front, near_fist[0], near_fist[1], 5.5, 5, PALETTE['o'], PALETTE['O'], PALETTE['n'])
	for i in range(3):
		put(front, round(near_fist[0]) + 2, round(near_fist[1]) - 2 + 2 * i, PALETTE['n'])
	return stack_layers([back, body, head, front])


def giant_zombie_frames():
	"""Idle x2, stomp x6, slam x3 (fists overhead, smash down, recover), roar x3 (head thrown back,
	arms spread, jaw hanging), charge windup x2 (head down, shoulder forward, fists back)."""
	frames = [giant_zombie_pose(), giant_zombie_pose(bob=-1, jaw=0.2)]
	frames += [giant_zombie_pose(t=i / 6, moving=True, bob=-1 if i % 3 == 1 else 0, lean=0.2) for i in range(6)]
	frames.append(giant_zombie_pose(near_fist=(48.0, 8.0), far_fist=(36.0, 6.0), head_back=0.3, jaw=0.4, bob=-2))
	frames.append(giant_zombie_pose(near_fist=(58.0, 57.0), far_fist=(52.0, 57.0), lean=1.0, jaw=1.0, bob=2))
	frames.append(giant_zombie_pose(near_fist=(54.0, 48.0), far_fist=(46.0, 50.0), lean=0.5, jaw=0.4, bob=1))
	frames.append(giant_zombie_pose(near_fist=(56.0, 34.0), far_fist=(14.0, 30.0), head_back=0.5, jaw=0.6))
	frames.append(giant_zombie_pose(near_fist=(60.0, 26.0), far_fist=(10.0, 22.0), head_back=1.0, jaw=1.0, bob=-1))
	frames.append(giant_zombie_pose(near_fist=(58.0, 30.0), far_fist=(12.0, 26.0), head_back=0.8, jaw=0.9))
	frames.append(giant_zombie_pose(near_fist=(36.0, 50.0), far_fist=(28.0, 48.0), lean=1.0, jaw=0.5, bob=1))
	frames.append(giant_zombie_pose(near_fist=(34.0, 52.0), far_fist=(26.0, 50.0), lean=1.0, jaw=0.7, bob=2))
	return frames


def shaded_ellipse(canvas, cx, cy, rx, ry, base, light, dark):
	"""Ellipse lit from the top left: light rim on the upper left, dark rim on the lower right."""
	for y in range(len(canvas)):
		for x in range(len(canvas[0])):
			dx = (x + 0.5 - cx) / rx
			dy = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			facing = -0.55 * dx - 0.8 * dy
			if facing > 0.55:
				canvas[y][x] = light
			elif facing < -0.5:
				canvas[y][x] = dark
			else:
				canvas[y][x] = base


def stack_layers(layers, width=64, height=64):
	"""Outlines each layer on its own and stacks them back to front, so overlapping parts stay readable."""
	canvas = new_canvas(width, height)
	for layer in layers:
		outlined = add_outline(layer)
		for y in range(height):
			for x in range(width):
				if outlined[y][x] is not None:
					canvas[y][x] = outlined[y][x]
	return canvas


def jointed_limb(canvas, points, thickness, color, joint_color=None):
	"""Thick segments through the points; joints get a dot in joint_color."""
	for start, end in zip(points, points[1:]):
		thick_line(canvas, start[0], start[1], end[0], end[1], thickness, color)
	if joint_color is not None:
		for x, y in points[1:-1]:
			put(canvas, round(x - 0.5), round(y - 0.5), joint_color)


## Broodmother near side legs front to back: (anchor, knee, foot) in 64x64 space, side view facing right.
BROOD_LEGS = [
	((48.0, 42.0), (57.0, 24.0), (63.0, 61.0)),
	((45.0, 44.0), (50.0, 26.0), (54.0, 62.0)),
	((41.0, 42.0), (33.0, 14.0), (26.0, 62.0)),
	((39.0, 42.0), (21.0, 10.0), (6.0, 61.0)),
]
BROOD_GROUND = 62


def broodmother_pose(t=0.0, moving=False, raise_front=0.0, crouch=0.0, rear=0.0, bob=0, curl=0.0, dead=False):
	"""64x64 side view spider facing right.
	t is the gait phase, raise_front lifts the front leg pair (web throw), crouch lowers the body
	and spreads the legs (brood launch), rear tilts the head up, bob lifts the whole body in pixels.
	curl pulls the legs in under the body (dead spider), dead puts out the eyes."""
	body_y = bob + round(4 * crouch)
	head_lift = round(-5 * rear)

	def leg_points(index, near):
		anchor, knee, foot = BROOD_LEGS[index]
		phase = t + (0.0 if (index % 2 == 0) == near else 0.5)
		swing = 3.0 * math.sin(2 * math.pi * phase) if moving else 0.0
		lift = 3.0 * max(0.0, math.cos(2 * math.pi * phase)) if moving else 0.0
		outward = 1 if foot[0] > anchor[0] else -1
		foot_x = foot[0] + swing + outward * 4 * crouch
		foot_y = foot[1] - lift
		knee_x = knee[0] + outward * 2 * crouch
		knee_y = knee[1] + body_y + 4 * crouch - 0.6 * lift
		anchor_y = anchor[1] + body_y + (head_lift if index < 2 else 0)
		if index < 2 and raise_front > 0:
			# front legs leave the ground and rise in a threat pose above the head
			raised_knee = (54.0 - 5 * index, 13.0 + 4 * index + head_lift)
			raised_foot = (63.0 - 4 * index, 25.0 + 4 * index + head_lift)
			knee_x += (raised_knee[0] - knee_x) * raise_front
			knee_y += (raised_knee[1] - knee_y) * raise_front
			foot_x += (raised_foot[0] - foot_x) * raise_front
			foot_y += (raised_foot[1] - foot_y) * raise_front
		if not near:
			foot_x -= 5 * outward
			knee_x -= 3 * outward
			knee_y += 3
		if curl > 0:
			# knees stick out below the body and the feet hook back in towards it
			curled_knee = (anchor[0] + outward * (8 + 3 * (index % 2)), anchor_y + 15)
			curled_foot = (anchor[0] + outward * 1, anchor_y + 19)
			knee_x += (curled_knee[0] - knee_x) * curl
			knee_y += (curled_knee[1] - knee_y) * curl
			foot_x += (curled_foot[0] - foot_x) * curl
			foot_y += (curled_foot[1] - foot_y) * curl
		return [(anchor[0], anchor_y), (knee_x, knee_y), (foot_x, foot_y)]

	far_legs = new_canvas(64, 64)
	for i in range(4):
		jointed_limb(far_legs, leg_points(i, False), 2.0, PALETTE['x'])
	# near back legs arch over the abdomen from behind it, near front legs pass behind the head
	back_legs = new_canvas(64, 64)
	for i in (2, 3):
		jointed_limb(back_legs, leg_points(i, True), 2.6, PALETTE['X'], PALETTE['Y'])
	body = new_canvas(64, 64)
	shaded_ellipse(body, 20, 37 + body_y, 18, 15, PALETTE['x'], PALETTE['X'], PALETTE['k'])
	# crimson hourglass bands and a clutch of eggs on her back
	for x0, x1 in ((9, 12), (17, 19), (25, 26)):
		thick_line(body, x0, 29 + body_y, x1, 47 + body_y, 2.2, PALETTE['m'])
	ellipse(body, 30, 40 + body_y, 2.0, 3.5, PALETTE['R'])
	for x, y in ((11, 24), (17, 22), (23, 23), (14, 28), (20, 27)):
		ellipse(body, x, y + body_y, 2.6, 2.2, PALETTE['e'])
		put(body, x - 1, y - 1 + body_y, PALETTE['w'])
	head = new_canvas(64, 64)
	head_y = 40 + body_y + head_lift
	shaded_ellipse(head, 45, head_y, 10, 8, PALETTE['X'], PALETTE['Y'], PALETTE['x'])
	for x, y, r in ((50, -4, 1.8), (53, -2, 1.8), (47, -6, 1.1), (51, -7, 1.1), (55, 1, 1.1)):
		ellipse(head, x, head_y + y, r, r, PALETTE['m'] if dead else PALETTE['R'])
	thick_line(head, 51, head_y + 4, 54, head_y + 10, 2.6, PALETTE['x'])
	thick_line(head, 54, head_y + 9, 53, head_y + 12, 1.4, PALETTE['w'])
	front_legs = new_canvas(64, 64)
	for i in (0, 1):
		jointed_limb(front_legs, leg_points(i, True), 2.6, PALETTE['X'], PALETTE['Y'])
	# fully raised front legs are seen in front of the head
	if raise_front > 0.75:
		return stack_layers([far_legs, back_legs, body, head, front_legs])
	return stack_layers([far_legs, back_legs, body, front_legs, head])


def broodmother_frames():
	"""Idle x2, crawl x6, web throw x3 (rears up, front legs raised, strikes), brood x3 (crouches, abdomen heaves)."""
	frames = [broodmother_pose(), broodmother_pose(bob=-1)]
	frames += [broodmother_pose(t=i / 6, moving=True, bob=-1 if i % 3 == 1 else 0) for i in range(6)]
	frames.append(broodmother_pose(raise_front=0.5, rear=0.5))
	frames.append(broodmother_pose(raise_front=1.0, rear=1.0))
	frames.append(broodmother_pose(raise_front=0.2, rear=0.0, bob=1))
	frames.append(broodmother_pose(crouch=0.5))
	frames.append(broodmother_pose(crouch=1.0))
	frames.append(broodmother_pose(crouch=0.3, bob=-2))
	return frames


def plague_mother_pose(t=0.0, moving=False, hand=None, swell=0.0, glow=False, mouth=0.0, hunch=0.0, bob=0, dead=False):
	"""64x64 hunched, bloated zombie matriarch facing right, acid sacs growing out of her back.
	hand is where the near arm reaches (None hangs it down), swell grows the sacs (negative empties them),
	glow lights them, mouth opens the jaw, hunch drops the head forward, bob lifts the whole body in pixels.
	dead puts out the eyes."""
	stride = math.sin(2 * math.pi * t) if moving else 0.0
	body_y = bob
	head_x = 46 + round(3 * hunch)
	head_y = 25 + body_y + round(5 * hunch)
	shoulder = (41.0, 30.0 + body_y)
	if hand is None:
		hand = (52.0 + 2 * stride, 52.0 + body_y)

	back = new_canvas(64, 64)
	# far leg and arm in shadow
	thick_line(back, 35 - 3 * stride, 50 + body_y, 37 - 4 * stride, 61, 6, PALETTE['z'])
	jointed_limb(back, [(36, 31 + body_y), (40 - 2 * stride, 43 + body_y), (44 - 2 * stride, 53 + body_y)], 4, PALETTE['z'])
	body = new_canvas(64, 64)
	thick_line(body, 24 + 3 * stride, 50 + body_y, 22 + 4 * stride, 61, 7, PALETTE['q'])
	thick_line(body, 20 + 4 * stride, 61, 27 + 4 * stride, 61, 3, PALETTE['z'])
	# bloated, veined belly hanging over a torn skirt
	shaded_ellipse(body, 30, 40 + body_y, 19, 16, PALETTE['q'], PALETTE['Q'], PALETTE['z'])
	shaded_ellipse(body, 35, 44 + body_y, 11, 10, PALETTE['Q'], PALETTE['Q'], PALETTE['q'])
	shaded_ellipse(body, 28, 53 + body_y, 18, 6, PALETTE['v'], PALETTE['p'], PALETTE['B'])
	for x in range(12, 46, 5):
		thick_line(body, x, 55 + body_y, x + 1, 59 + body_y, 2, PALETTE['v'])
	jointed_limb(body, [(28, 34 + body_y), (32, 40 + body_y), (30, 46 + body_y)], 1, PALETTE['p'])
	jointed_limb(body, [(40, 38 + body_y), (38, 43 + body_y), (42, 48 + body_y)], 1, PALETTE['p'])
	ellipse(body, 37, 45 + body_y, 1.6, 1.6, PALETTE['a'])
	# acid sacs bulging from the hunched back; the summon swells and lights them
	sac_core = PALETTE['y'] if glow else PALETTE['A']
	for x, y, r in ((15, 30, 6.0), (22, 21, 5.0), (10, 41, 4.5), (31, 18, 3.5)):
		rr = r + swell
		ellipse(body, x, y + body_y, rr, rr, PALETTE['t'])
		ellipse(body, x, y + body_y, rr - 1.2, rr - 1.2, PALETTE['a'])
		core = rr * 0.35 + (0.6 if glow else 0)
		ellipse(body, x - rr * 0.3, y + body_y - rr * 0.3, core, core, sac_core)
	# torn shawl draped from the back over the shoulders into a hood
	shawl = new_canvas(64, 64)
	jointed_limb(shawl, [(30, 26 + body_y), (38, 24 + body_y), (head_x - 3, head_y - 2)], 7, PALETTE['p'])
	shaded_ellipse(shawl, head_x - 1, head_y - 1, 9, 8.5, PALETTE['p'], PALETTE['P'], PALETTE['v'])
	for x in range(32, 44, 4):
		thick_line(shawl, x, 27 + body_y, x - 1, 33 + body_y, 2, PALETTE['v'])
	head = new_canvas(64, 64)
	shaded_ellipse(head, head_x + 2, head_y + 1, 6, 6, PALETTE['q'], PALETTE['Q'], PALETTE['z'])
	# sunken sockets with glowing eyes
	for x in (head_x + 2, head_x + 5):
		ellipse(head, x, head_y - 0.5, 1.4, 1.4, PALETTE['k'])
		put(head, x, head_y - 1, PALETTE['z'] if dead else PALETTE['y'])
	jaw = 1.0 + 3.0 * mouth
	ellipse(head, head_x + 4, head_y + 3.5 + jaw / 2, 2.6, jaw, PALETTE['k'])
	for x in (head_x + 3, head_x + 5):
		put(head, x, head_y + 3, PALETTE['w'])
	thick_line(head, head_x + 4, head_y + 4 + jaw, head_x + 4 + stride, head_y + 9 + 3 * mouth, 1.4, PALETTE['a'])
	front = new_canvas(64, 64)
	elbow = ((shoulder[0] + hand[0]) / 2 + 3, (shoulder[1] + hand[1]) / 2 + 2)
	jointed_limb(front, [shoulder, elbow, hand], 5, PALETTE['q'])
	ellipse(front, hand[0], hand[1], 2.6, 2.4, PALETTE['q'])
	for dx in (-2, 0, 2):
		thick_line(front, hand[0] + dx, hand[1] + 1, hand[0] + dx * 1.5 + 1, hand[1] + 5, 1.2, PALETTE['Q'])
	if hand[1] < 40:
		# acid gob held in the throwing hand
		ellipse(front, hand[0], hand[1] - 3, 3, 3, PALETTE['a'])
		put(front, round(hand[0]) - 1, round(hand[1]) - 4, PALETTE['A'])
	return stack_layers([back, body, shawl, head, front])


def plague_mother_frames():
	"""Idle x2 (sacs breathe), waddle x6, acid throw x3 (arm winds over the head, flings, recovers),
	summon x3 (hunches, sacs swell and glow, retches)."""
	frames = [plague_mother_pose(), plague_mother_pose(swell=0.6, bob=-1)]
	frames += [plague_mother_pose(t=i / 6, moving=True, bob=-1 if i % 3 == 1 else 0) for i in range(6)]
	frames.append(plague_mother_pose(hand=(30.0, 8.0), mouth=0.3, bob=-1))
	frames.append(plague_mother_pose(hand=(62.0, 26.0), mouth=1.0))
	frames.append(plague_mother_pose(hand=(56.0, 44.0), mouth=0.4, bob=1))
	frames.append(plague_mother_pose(swell=0.8, hunch=0.5, mouth=0.5))
	frames.append(plague_mother_pose(swell=1.8, glow=True, hunch=1.0, mouth=1.0, bob=1))
	frames.append(plague_mother_pose(swell=1.0, glow=True, hunch=0.6, mouth=0.6))
	return frames


def web_trap_frame():
	"""A sticky web tile on the floor: spokes from the centre joined by rings, no outline."""
	canvas = new_canvas(16, 16)
	for angle in range(0, 360, 45):
		radians = math.radians(angle)
		thick_line(canvas, 8, 8, 8 + 7 * math.cos(radians), 8 + 7 * math.sin(radians), 1.0, PALETTE['e'])
	# Two thin rings between the spokes, so it reads as a web and not a target.
	for radius in (3.5, 6.0):
		for y in range(16):
			for x in range(16):
				distance = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
				if abs(distance - radius) <= 0.35:
					canvas[y][x] = PALETTE['e']
	canvas[8][8] = PALETTE['w']
	return canvas


def acid_puddle_frame():
	"""A flat acid pool, 24 wide: teal body with a darker rim and bright highlights."""
	canvas = new_canvas(24, 16)
	ellipse(canvas, 12, 8, 11.5, 7.0, PALETTE['t'])
	ellipse(canvas, 12, 8, 10.0, 5.8, PALETTE['a'])
	ellipse(canvas, 8, 6, 2.0, 1.0, PALETTE['A'])
	ellipse(canvas, 16, 10, 1.0, 0.7, PALETTE['A'])
	return canvas


def slime_puddle_frame():
	"""A flat slime pool, 24 wide: blue body with a darker rim and a highlight."""
	canvas = new_canvas(24, 16)
	ellipse(canvas, 12, 8, 11.5, 7.0, PALETTE['s'])
	ellipse(canvas, 12, 8, 10.0, 5.8, PALETTE['S'])
	ellipse(canvas, 8, 6, 2.0, 1.0, PALETTE['L'])
	return canvas


def write_png(path, rows):
	"""Writes RGBA rows (None means transparent) as a PNG using zlib and struct."""
	height = len(rows)
	width = len(rows[0])
	raw = bytearray()
	for row in rows:
		raw.append(0)
		for pixel in row:
			raw.extend(TRANSPARENT if pixel is None else pixel)

	def chunk(tag, data):
		return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

	header = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
	data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
	with open(path, 'wb') as file:
		file.write(data)


def write_strip(path, frames):
	"""Joins square frames left to right into one PNG; works for 16x16 and 64x64 frames."""
	height = len(frames[0])
	rows = []
	for y in range(height):
		row = []
		for frame in frames:
			row.extend(frame[y])
		rows.append(row)
	write_png(path, rows)


## Each slime/zombie is a 16x16 map of palette keys: one string per row, centred.
BLOATER_MAP = [
	'', 'llllll', 'gggggggg', 'gRggRg', 'gggggggggg', 'ggppppppppgg',
	'gppPppppPppg', 'gppppppppppg', 'gggpppppggg', 'gggggggggg',
	'rrrrrrrrrr', 'rrrrrrrr', 'bb....bb', 'bb....bb', 'bbb..bbb', '',
]
ACID_SLIME_MAP = [
	'', '', 'a.a..a.a', 'aaaaaaaaaa', 'aAaaaaaaaaa', 'aaRaaaaRaaa',
	'aaaaaaaaaaaa', 'aaaaaAaaaaaa', 'aaaaaaaaaaaa', 'aaaaaaaaaaa',
	'tttttttttttt', 'a.a.a.a.a.a', '', '', '', '',
]


def main():
	characters = os.path.join(HERE, 'characters')
	projectile = os.path.join(HERE, 'projectile')

	write_strip(os.path.join(characters, 'bloater_16x16_strip8.png'), walk_frames(from_rows(BLOATER_MAP)))
	write_strip(os.path.join(characters, 'acid_slime_16x16_strip8.png'), walk_frames(from_rows(ACID_SLIME_MAP)))
	write_strip(
		os.path.join(characters, 'skitter_spider_16x16_strip8.png'),
		spider_crawl_frames(PALETTE['X'], PALETTE['x'], PALETTE['Y'], PALETTE['X'], PALETTE['R'], PALETTE['w'], marks=PALETTE['R']),
	)
	write_strip(
		os.path.join(characters, 'web_spider_16x16_strip8.png'),
		spider_crawl_frames(PALETTE['X'], PALETTE['e'], PALETTE['Y'], PALETTE['X'], PALETTE['R'], PALETTE['w'], marks=PALETTE['p']),
	)
	write_png(
		os.path.join(characters, 'skitter_spider_dead_16x16.png'),
		spider_frames(PALETTE['X'], PALETTE['x'], PALETTE['Y'], PALETTE['R'], PALETTE['w'], marks=PALETTE['R'])[0],
	)
	write_png(
		os.path.join(characters, 'web_spider_dead_16x16.png'),
		spider_frames(PALETTE['X'], PALETTE['e'], PALETTE['Y'], PALETTE['R'], PALETTE['w'], marks=PALETTE['p'])[0],
	)

	write_strip(os.path.join(characters, 'giant_zombie_64x64.png'), giant_zombie_frames())
	write_strip(os.path.join(characters, 'plague_mother_64x64.png'), plague_mother_frames())
	write_strip(os.path.join(characters, 'broodmother_64x64.png'), broodmother_frames())

	write_png(os.path.join(characters, 'bloater_dead_16x16.png'), bloater_dead_frame())
	write_png(os.path.join(characters, 'acid_slime_dead_16x16.png'), acid_slime_dead_frame())
	write_png(os.path.join(characters, 'giant_zombie_dead_64x64.png'), giant_zombie_dead_frame())
	write_png(os.path.join(characters, 'broodmother_dead_64x64.png'), broodmother_dead_frame())
	write_png(os.path.join(characters, 'plague_mother_dead_64x64.png'), plague_mother_dead_frame())

	write_png(os.path.join(HERE, 'weapon', 'fist_0.png'), fist_sprite())
	write_strip(os.path.join(HERE, 'vfx', 'punch_16x16_strip4.png'), punch_frames())

	write_png(os.path.join(projectile, 'acid_spit_8x8.png'), acid_spit_projectile())
	write_png(os.path.join(projectile, 'web_8x8.png'), web_projectile())

	write_png(os.path.join(HERE, 'misc', 'web_trap_16x16.png'), web_trap_frame())
	write_png(os.path.join(HERE, 'misc', 'acid_puddle_24x16.png'), acid_puddle_frame())
	write_png(os.path.join(HERE, 'misc', 'slime_puddle_24x16.png'), slime_puddle_frame())


if __name__ == '__main__':
	main()
