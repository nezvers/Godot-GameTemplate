#!/usr/bin/env python3
"""Industrial metal, sandstone ruins and flesh hive looks for the isometric tilesets.

Pure standard library, like generate_tile_variants.py. Unlike the mossy/bloody overlays,
these are full re-skins: no base colour survives. The base atlases only give each tile its
shape, so the autotiler, colliders and y-sort keep working:

- alpha: copied as is, so every footprint matches the base,
- border lines: the dark lines along a floor's raised edges stay edges,
- shading: the lit and shadowed halves of walls and hole sides keep their brightness order,
- void: the bottomless inside of holes stays void,
- cracks: the extra lines of the cracked floor tiles stay cracks.

Everything else (stone seams, bricks, colours) is dropped and painted from scratch:

    python3 generate_tile_themes.py

Output, next to each base atlas: tilesets/<atlas>_<theme>.png for metal, sandstone and flesh.

The plain floor tile covers most of a room, so its pattern repeats every tile: floors use
patterns that repeat every 16 iso units (seamless), and the random dents, chips and
pustules go only on the cracked tiles. Each 32x32 atlas cell gets its own seeded random
generator, so reruns give the same pixels.
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
from generate_tile_variants import ATLASES, CELL, TILESETS, VOID_LUMA, luma, read_png, write_png

THEMES = ['metal', 'sandstone', 'flesh']

## Floor atlas cells of the cracked floor tiles, and the plain tile every floor tile is compared with.
CRACKED = [(1, 3), (2, 3), (3, 3)]
UNCRACKED = (0, 3)

## Dark to light ramps. Index 3 is the plain surface; shading and patterns step up or down.
RAMPS = {
	'metal': {
		'floor': [(30, 33, 38), (50, 55, 62), (72, 79, 88), (96, 104, 114), (114, 123, 133), (140, 149, 158), (180, 188, 196)],
		# painted blue-grey steel, so the walls stand apart from the bare grey floor plates
		'wall': [(8, 11, 16), (16, 23, 33), (26, 38, 54), (38, 55, 76), (54, 76, 102), (78, 102, 130), (116, 140, 166)],
		'hole': [(8, 9, 11), (16, 18, 22), (25, 28, 33), (35, 39, 45), (47, 52, 59), (62, 68, 76), (82, 88, 96)],
	},
	'sandstone': {
		'floor': [(70, 48, 30), (110, 80, 50), (146, 110, 70), (176, 138, 90), (196, 158, 106), (216, 182, 130), (236, 210, 162)],
		'wall': [(30, 20, 14), (46, 32, 22), (64, 46, 30), (84, 62, 40), (106, 80, 52), (130, 100, 66), (156, 124, 84)],
		'hole': [(16, 10, 7), (28, 19, 13), (42, 30, 20), (56, 41, 28), (72, 54, 36), (92, 70, 48), (116, 90, 62)],
	},
	'flesh': {
		'floor': [(52, 12, 22), (86, 22, 34), (118, 36, 46), (148, 56, 62), (170, 74, 76), (200, 108, 104), (232, 158, 146)],
		'wall': [(26, 6, 12), (42, 10, 20), (62, 18, 30), (84, 28, 42), (108, 42, 56), (134, 60, 72), (162, 84, 94)],
		'hole': [(18, 3, 8), (32, 7, 15), (48, 13, 24), (66, 20, 34), (86, 30, 46), (108, 44, 60), (134, 62, 78)],
	},
}

VOID = {'metal': (5, 5, 7), 'sandstone': (12, 7, 5), 'flesh': (22, 2, 8)}

HAZARD = [(214, 172, 40), (34, 31, 26)]
RUST = [(78, 40, 24), (112, 58, 30), (148, 80, 38), (176, 106, 52)]
VEIN = [(70, 18, 58), (98, 30, 76), (128, 46, 96)]
BONE = [(150, 136, 108), (194, 182, 150), (228, 220, 192)]
PUS = [(150, 140, 60), (196, 186, 92)]


def iso(x, y):
	"""Pixel -> isometric (u, v) on the floor plane, -8..8 across a tile."""
	px = x + 0.5 - 16
	py = y + 0.5 - 8
	return px / 2 + py, -px / 2 + py


def face(x, y, rising):
	"""Pixel -> (along, depth) on the pit side a hole tile shows. The pit has two wall planes:
	the shadowed one runs along '/' (rising), the lit one along '\\'. Which plane a face is
	depends on its tone, not on which half it sits in: a straight pit side covers both halves
	with one plane, and only a corner tile has both. Depth is measured across the courses over
	the whole tile, so a course runs on into the next tile of the same side."""
	if rising:
		return x, y + (x + 0.5) / 2 - 8
	return x, y - (x + 0.5 - 16) / 2


def lattice(i, j, period, seed):
	i %= period
	j %= period
	h = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h & 0xFFFF) / 65535.0


def noise(u, v, spacing, seed):
	"""Smooth value noise that repeats every 16 units, so it runs on across tile borders."""
	period = int(16 / spacing)
	fu, fv = u / spacing, v / spacing
	i, j = math.floor(fu), math.floor(fv)
	tu, tv = fu - i, fv - j
	tu, tv = tu * tu * (3 - 2 * tu), tv * tv * (3 - 2 * tv)
	a = lattice(i, j, period, seed)
	b = lattice(i + 1, j, period, seed)
	c = lattice(i, j + 1, period, seed)
	d = lattice(i + 1, j + 1, period, seed)
	return (a * (1 - tu) + b * tu) * (1 - tv) + (c * (1 - tu) + d * tu) * tv


class Shape:
	"""What the base art says about one 32x32 cell: footprint, edges, shading, void, cracks."""

	def __init__(self, rows, cx, cy, kind):
		self.kind = kind
		self.cell = (cx, cy)
		self.ox = cx * CELL
		self.oy = cy * CELL
		self.alpha = {}
		for y in range(CELL):
			for x in range(CELL):
				a = rows[self.oy + y][self.ox + x][3]
				if a > 0:
					self.alpha[(x, y)] = a
		self.luma = {p: luma(rows[self.oy + p[1]][self.ox + p[0]]) for p in self.alpha}
		self.role = {}
		self.light = {}
		if not self.alpha:
			return
		lumas = sorted(self.luma.values())
		median = lumas[len(lumas) // 2]
		for p, l in self.luma.items():
			if kind == 'floor':
				body = median
			else:
				body = self._local_median(p)
			if kind == 'hole' and body < VOID_LUMA:
				self.role[p] = 'void'
			elif l < body - 6:
				self.role[p] = 'border' if self._near_outline(p) else 'line'
			else:
				self.role[p] = 'body'
			self.light[p] = body
		if kind != 'floor':
			self._read_halves()

	## A wall or hole tile is two faces: the left half (x < 16) and the right half. Each base
	## face is brick (mortar lines: a wall's inner, room-facing side) or plain (a wall's outer
	## side), and dark or lit. The autotiler picks tiles by exactly this, so a re-skin must keep it.
	BRICK_LINES = 0.15

	def _read_halves(self):
		self.half = {}
		for h in (0, 1):
			pixels = [p for p, r in self.role.items() if (p[0] >= 16) == h and r != 'void']
			if not pixels:
				continue
			lines = sum(1 for p in pixels if self.role[p] != 'body')
			body = sorted(self.luma[p] for p in pixels if self.role[p] == 'body') or [0]
			self.half[h] = {'brick': lines > self.BRICK_LINES * len(pixels), 'tone': body[len(body) // 2], 'step': 3}

	def half_of(self, p):
		return self.half.get(1 if p[0] >= 16 else 0)

	def brick_at(self, p):
		half = self.half_of(p)
		return half is not None and half['brick']

	def _local_median(self, p):
		window = sorted(self.luma[(p[0] + dx, p[1] + dy)] for dx in range(-2, 3) for dy in range(-2, 3) if (p[0] + dx, p[1] + dy) in self.luma)
		return window[len(window) // 2]

	def _near_outline(self, p):
		x, y = p
		for d in range(1, 5):
			if (x - d, y) not in self.alpha or (x + d, y) not in self.alpha:
				return True
		for d in range(1, 3):
			if (x, y - d) not in self.alpha or (x, y + d) not in self.alpha:
				return True
		return False

	def compare_with_plain(self, plain, cracked):
		"""Floor lines the plain tile has too are just grout between tiles; the rest are real:
		edges along the outline, and cracks inside on the cracked tiles."""
		for p, role in self.role.items():
			if self is plain or plain.role.get(p) in ('border', 'line'):
				if role == 'border':
					self.role[p] = 'line'
			elif role == 'line' and cracked:
				self.role[p] = 'crack'

	def is_role(self, x, y, *roles):
		return self.role.get((x, y)) in roles


class Painter:
	"""Shared pixel plumbing for every theme. A theme fills in body/border/crack and extras."""

	def __init__(self, theme, shape, rng, seed):
		self.theme = theme
		self.shape = shape
		self.kind = shape.kind
		self.rng = rng
		self.seed = seed
		self.ramp = RAMPS[theme][shape.kind]
		self.out = {}

	def shade(self, p):
		"""How many ramp steps the base art's lit/shadowed face moves this pixel (see face_steps)."""
		if self.kind == 'floor':
			return 0
		return self.shape.half_of(p)['step'] - 3

	def color(self, index):
		return self.ramp[max(0, min(len(self.ramp) - 1, index))]

	def put(self, p, color):
		if p in self.shape.alpha:
			self.out[p] = color

	def body_pixels(self):
		return sorted(p for p, r in self.shape.role.items() if r == 'body')

	def cracked(self):
		return self.kind == 'floor' and self.shape.cell in CRACKED

	def blob(self, cx, cy, rx, ry, pick):
		for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
			for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
				dx = (x + 0.5 - cx) / rx
				dy = (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0 - 0.35 * self.rng.random() and self.shape.is_role(x, y, 'body'):
					self.put((x, y), pick(x, y))

	def paint(self):
		for p in sorted(self.shape.role):
			role = self.shape.role[p]
			if role == 'void':
				self.put(p, VOID[self.theme])
			elif role == 'border' and self.kind == 'floor':
				self.put(p, self.border(p))
			elif role == 'crack':
				self.put(p, self.crack(p))
			elif self.kind == 'floor':
				# base seams are not kept: they get the surface like their neighbours
				self.put(p, self.floor(p, *iso(*p)))
			elif self.kind == 'wall':
				# inner (brick) faces get the theme's pattern, outer faces stay smooth
				paint = self.wall if self.shape.brick_at(p) else self.plain
				self.put(p, paint(p, 3 + self.shade(p), *p))
			else:
				# the shadowed (darker) pit wall is the '/' plane, the lit one the '\' plane
				self.put(p, self.side(p, 3 + self.shade(p), *face(*p, self.shade(p) < 0)))
		self.extras()
		return self.out

	def plain(self, p, i, x, y):
		# a wall's outer face: the base draws it as one flat colour, so only a faint grain
		# that runs along the wall plane like the courses
		along, depth = face(x, y, self.shade(p) < 0)
		return self.color(i + 1) if noise(along, 2 * depth, 4, 13) > 0.8 else self.color(i)

	def face_pixels(self):
		"""Body pixels that may carry decoration: on walls only the inner (brick) faces."""
		return [p for p in self.body_pixels() if self.kind != 'wall' or self.shape.brick_at(p)]

	def extras(self):
		pass


class Metal(Painter):
	def floor(self, p, u, v):
		# one tread plate per tile: lit and shadowed bevel, raised lugs, a rivet in each corner
		if u > 7.0 or v > 7.0:
			return self.color(2)
		if u < -7.0 or v < -7.0:
			return self.color(4)
		if abs(abs(u) - 5.2) < 0.8 and abs(abs(v) - 5.2) < 0.8:
			return self.color(6)
		lu, lv = (u + 8) % 4, (v + 8) % 4
		if 1.0 <= lu < 2.0 and 1.0 <= lv < 2.0:
			return self.color(4)
		return self.color(3)

	def wall(self, p, i, x, y):
		# Wall tiles stack into tall faces, so wall patterns run straight down and repeat
		# every 8 pixels across and down: upright panels with a black seam, a lit edge and
		# rivets with a shadow under them.
		if x % 8 == 0:
			return self.color(0)
		if x % 8 == 1:
			return self.color(i + 2)
		if x % 8 == 4 and y % 8 == 3:
			return self.color(i + 3)
		if x % 8 == 4 and y % 8 == 4:
			return self.color(i - 2)
		return self.color(i)

	def plain(self, p, i, x, y):
		# the outer face: smooth sheet with a faint seam between wide panels
		return self.color(i - 1) if x % 16 == 0 else self.color(i)

	def side(self, p, i, along, depth):
		# riveted panels in courses down the shaft
		course = int(depth // 4)
		if depth % 4 < 1.0:
			return self.color(i - 2)
		if (along + 8 * (course % 2)) % 16 < 1.0:
			return self.color(i - 1)
		if depth % 4 < 2.0 and (along + 8 * (course % 2)) % 16 in (2, 13):
			return self.color(i + 3)
		return self.color(i)

	def border(self, p):
		return HAZARD[((p[0] + p[1]) // 3) % 2]

	def crack(self, p):
		return self.color(0)

	def extras(self):
		pool = self.body_pixels()
		if not pool:
			return
		if self.cracked():
			# dented, rusting plate around the cracks
			for p in sorted(self.shape.role):
				if self.shape.role[p] == 'crack':
					if self.shape.is_role(p[0], p[1] - 1, 'body'):
						self.put((p[0], p[1] - 1), self.color(5))
					if self.rng.random() < 0.25:
						self.blob(p[0], p[1], 1.5, 1.0, lambda x, y: RUST[self.rng.randint(1, 3)])
		elif self.kind != 'floor' and self.face_pixels() and self.rng.random() < 0.5:
			# a rust streak running down a panel
			faces = self.face_pixels()
			x, y = faces[self.rng.randrange(len(faces))]
			for step in range(self.rng.randint(2, 5)):
				if self.shape.is_role(x, y + step, 'body', 'line'):
					self.put((x, y + step), RUST[1 if step else 2])
		if self.kind == 'hole':
			# broken grate stubs sticking out over the shaft
			for p in sorted(self.shape.role):
				if self.shape.role[p] == 'void' and (p[0] + 2 * p[1]) % 6 == 0:
					x, y = p
					if any(self.shape.is_role(x + dx, y + dy, 'body', 'line') for dx, dy in ((-1, 0), (1, 0), (0, -1))):
						self.put(p, self.color(5))


class Sandstone(Painter):
	def floor(self, p, u, v):
		# four flagstones per tile with chiselled joints, sun on the far lip, sandy grain
		au, av = (u + 8) % 8, (v + 8) % 8
		if au < 0.7 or av < 0.7:
			return self.color(1)
		if au < 1.5 or av < 1.5:
			return self.color(4)
		grain = noise(u, v, 2, self.seed % 7)
		if grain > 0.78:
			return self.color(4)
		if grain < 0.2:
			return self.color(2)
		return self.color(3)

	def wall(self, p, i, x, y):
		# dressed blocks laid in courses along the wall plane, like the base bricks: the shadowed
		# face runs along '/', the lit one along '\', with upright staggered joints and sandy grain
		along, depth = face(x, y, self.shade(p) < 0)
		course = int(depth // 4)
		if depth % 4 < 1.0 or (along + 4 * (course % 2)) % 8 < 1.0:
			return self.color(i - 2)
		grain = noise(along, 2 * depth, 4, 5)
		if grain > 0.72:
			return self.color(i + 1)
		if grain < 0.28:
			return self.color(i - 1)
		return self.color(i)

	def side(self, p, i, along, depth):
		# staggered blocks, each with a lit top course and a dark mortar line
		course = int(depth // 3)
		if depth % 3 < 1.0:
			return self.color(i - 2)
		if (along + 3 * (course % 2)) % 6 < 1.0:
			return self.color(i - 2)
		if depth % 3 < 2.0:
			return self.color(i + 1)
		return self.color(i)

	def border(self, p):
		# a worn lip: dark outer row, lit row inside it
		x, y = p
		inner = any(self.shape.is_role(x + dx, y + dy, 'body') for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
		return self.color(5 if inner else 1)

	def crack(self, p):
		return self.color(0)

	def extras(self):
		pool = self.body_pixels()
		if not pool:
			return
		if self.cracked():
			# chips knocked out of the stone
			for _ in range(self.rng.randint(2, 4)):
				x, y = pool[self.rng.randrange(len(pool))]
				self.put((x, y), self.color(1))
				self.put((x + 1, y), self.color(2))
				self.put((x, y - 1), self.color(5))
		if self.kind == 'hole':
			# the rim crumbles into the pit
			for p in sorted(self.shape.role):
				if self.shape.role[p] == 'body' and self.rng.random() < 0.3:
					x, y = p
					if self.shape.is_role(x, y + 1, 'void') or self.shape.is_role(x - 1, y, 'void'):
						self.put(p, VOID[self.theme])


class Flesh(Painter):
	def floor(self, p, u, v):
		# mottled membrane threaded with veins, wet glints
		vein = noise(u, v, 4, 7)
		if abs(vein - 0.5) < 0.03:
			return VEIN[1]
		if abs(vein - 0.5) < 0.05:
			return VEIN[0]
		if noise(u, v, 2, 11) > 0.86:
			return self.color(5)
		return self.color(3 + int(round((noise(u, v, 4, 3) - 0.5) * 2.5)))

	def wall(self, p, i, x, y):
		# hanging sinews over mottled meat
		if x % 8 == 2:
			return self.color(i - 2)
		if x % 8 == 3:
			return self.color(i + 1)
		return self.color(i + int(round((noise(x, 2 * y, 4, 9) - 0.5) * 2.5)))

	def side(self, p, i, along, depth):
		# ribs across the pit side, a highlight on each; sinews between them
		rib = depth % 4
		if rib < 1.0:
			return self.color(i - 2)
		if 2.0 <= rib < 2.8:
			return self.color(i + 1)
		if along % 7 == 3:
			return self.color(i - 1)
		return self.color(i)

	def border(self, p):
		return VEIN[0] if (p[0] + p[1]) % 4 else self.color(5)

	def crack(self, p):
		# torn membrane
		return VOID[self.theme]

	def extras(self):
		pool = self.body_pixels()
		if not pool:
			return
		if self.cracked():
			# pustules round the tears
			for _ in range(self.rng.randint(1, 2)):
				x, y = pool[self.rng.randrange(len(pool))]
				self.blob(x, y, 1.6, 0.9, lambda px, py: PUS[0])
				self.put((x, y), PUS[1])
		elif self.kind == 'wall' and self.face_pixels() and self.rng.random() < 0.4:
			faces = self.face_pixels()
			x, y = faces[self.rng.randrange(len(faces))]
			self.put((x, y), PUS[1])
			self.put((x + 1, y), PUS[0])
		if self.kind == 'hole':
			# teeth around the maw
			for p in sorted(self.shape.role):
				if self.shape.role[p] in ('body', 'line') and self.shape.is_role(p[0], p[1] + 1, 'void') and self.rng.random() < 0.45:
					self.put(p, BONE[self.rng.randint(1, 2)])
					self.put((p[0], p[1] - 1), BONE[0])


PAINTERS = {'metal': Metal, 'sandstone': Sandstone, 'flesh': Flesh}

## Ramp steps the darkest and the lightest base face tone of an atlas map to.
FACE_STEPS = (2, 4)


def face_steps(shapes):
	"""Rank the face tones of a whole atlas (the base uses one dark and one lit tone) and spread
	them evenly over FACE_STEPS, so lit faces stay lighter without running off the ramp."""
	halves = [half for shape in shapes if shape.alpha for half in shape.half.values()]
	tones = sorted(set(half['tone'] for half in halves))
	low, high = FACE_STEPS
	for half in halves:
		rank = tones.index(half['tone'])
		half['step'] = low + int(round((high - low) * rank / max(1, len(tones) - 1)))


def make_theme(rows, name, kind, theme):
	out = [[(0, 0, 0, 0)] * len(rows[0]) for _ in rows]
	shapes = {}
	for cy in range(len(rows) // CELL):
		for cx in range(len(rows[0]) // CELL):
			shapes[(cx, cy)] = Shape(rows, cx, cy, kind)
	if kind == 'floor':
		for cell, shape in shapes.items():
			shape.compare_with_plain(shapes[UNCRACKED], cell in CRACKED)
	else:
		face_steps(shapes.values())
	for (cx, cy), shape in shapes.items():
		if not shape.alpha:
			continue
		seed = (sum(map(ord, name + theme)) * 7919 + cy * 131 + cx) & 0xFFFFFFFF
		painted = PAINTERS[theme](theme, shape, random.Random(seed), seed).paint()
		for (x, y), color in painted.items():
			out[shape.oy + y][shape.ox + x] = color + (shape.alpha[(x, y)],)
	return out


def main():
	for name, kind in ATLASES:
		rows = read_png(os.path.join(TILESETS, name + '.png'))
		for theme in THEMES:
			write_png(os.path.join(TILESETS, '%s_%s.png' % (name, theme)), make_theme(rows, name, kind, theme))


if __name__ == '__main__':
	main()
