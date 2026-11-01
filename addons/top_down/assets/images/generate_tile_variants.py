#!/usr/bin/env python3
"""Mossy and bloody variants of the isometric floor, wall and hole tilesets.

Pure standard library (zlib + struct), like generate_enemy_sprites.py.
It reads the hand-drawn atlases in tilesets/ and paints over them, so every
variant keeps the exact pixel footprint (alpha) of its base tile:

    python3 generate_tile_variants.py

Output, next to each base atlas:
- tilesets/<atlas>_mossy.png   moss in the grout, moss clumps, slime puddles and drips
- tilesets/<atlas>_bloody.png  blood splatters, smears, drips and the odd handprint

Each 32x32 atlas cell gets its own seeded random generator, so reruns give the same pixels.
"""
import os
import random
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
TILESETS = os.path.join(HERE, 'tilesets')
CELL = 32

## Every atlas: file name and what kind of tiles it holds.
ATLASES = [
	('tileset_isometric_floor', 'floor'),
	('tileset_isometric_walls', 'wall'),
	('tileset_isometric_holes', 'hole'),
]

MOSS = [(40, 72, 44), (62, 104, 56), (92, 140, 68), (132, 176, 86)]
SLIME = [(46, 104, 38), (88, 158, 54), (168, 222, 108)]
BLOOD = [(64, 12, 24), (100, 18, 30), (136, 26, 36), (172, 40, 42)]

## Pixels darker than this are the bottomless void inside holes; nothing grows or splatters there.
VOID_LUMA = 14


def read_png(path):
	"""Reads an 8-bit RGBA, non-interlaced PNG into rows of (r, g, b, a) tuples."""
	with open(path, 'rb') as file:
		data = file.read()
	assert data[:8] == b'\x89PNG\r\n\x1a\n', path
	pos = 8
	idat = b''
	width = height = 0
	while pos < len(data):
		length, = struct.unpack('>I', data[pos:pos + 4])
		tag = data[pos + 4:pos + 8]
		body = data[pos + 8:pos + 8 + length]
		pos += 12 + length
		if tag == b'IHDR':
			width, height, depth, color_type, _, _, interlace = struct.unpack('>IIBBBBB', body)
			assert depth == 8 and color_type == 6 and interlace == 0, '%s: only 8-bit RGBA, non-interlaced' % path
		elif tag == b'IDAT':
			idat += body
	raw = zlib.decompress(idat)
	stride = width * 4
	rows = []
	previous = bytearray(stride)
	i = 0
	for _ in range(height):
		kind = raw[i]
		line = bytearray(raw[i + 1:i + 1 + stride])
		i += 1 + stride
		for x in range(stride):
			left = line[x - 4] if x >= 4 else 0
			up = previous[x]
			up_left = previous[x - 4] if x >= 4 else 0
			if kind == 1:
				line[x] = (line[x] + left) & 255
			elif kind == 2:
				line[x] = (line[x] + up) & 255
			elif kind == 3:
				line[x] = (line[x] + (left + up) // 2) & 255
			elif kind == 4:
				p = left + up - up_left
				pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
				line[x] = (line[x] + (left if pa <= pb and pa <= pc else up if pb <= pc else up_left)) & 255
		previous = line
		rows.append([tuple(line[x * 4:x * 4 + 4]) for x in range(width)])
	return rows


def write_png(path, rows):
	"""Writes rows of (r, g, b, a) tuples as an RGBA PNG."""
	height = len(rows)
	width = len(rows[0])
	raw = bytearray()
	for row in rows:
		raw.append(0)
		for pixel in row:
			raw.extend(pixel)

	def chunk(tag, data):
		return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

	header = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
	data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
	with open(path, 'wb') as file:
		file.write(data)


def luma(pixel):
	return (pixel[0] * 299 + pixel[1] * 587 + pixel[2] * 114) // 1000


class Cell:
	"""One 32x32 atlas cell: which pixels can be painted, which are grout lines, and the paint on top."""

	def __init__(self, rows, cx, cy):
		self.rows = rows
		self.ox = cx * CELL
		self.oy = cy * CELL
		self.paint = {}
		self.surface = set()
		for y in range(CELL):
			for x in range(CELL):
				pixel = rows[self.oy + y][self.ox + x]
				if pixel[3] > 0 and luma(pixel) >= VOID_LUMA:
					self.surface.add((x, y))
		lumas = sorted(luma(self.pixel(x, y)) for x, y in self.surface)
		self.median = lumas[len(lumas) // 2] if lumas else 0
		## Grout and edge lines are the clearly darker pixels of the tile.
		self.grout = {(x, y) for x, y in self.surface if luma(self.pixel(x, y)) < self.median - 6}

	def pixel(self, x, y):
		return self.rows[self.oy + y][self.ox + x]

	def empty(self):
		return not self.surface

	def put(self, x, y, color):
		if (x, y) in self.surface:
			self.paint[(x, y)] = color

	def shade(self, x, y, palette, lift=0):
		"""Palette entry that follows the base pixel: grout gets the darkest shades, so the tile lines still read."""
		index = 0 if (x, y) in self.grout else 1 + lift
		return palette[max(0, min(len(palette) - 1, index))]

	def blob(self, rng, cx, cy, rx, ry, palette, ragged=0.35, lift=0):
		"""A squashed (isometric) blob with a ragged edge."""
		for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
			for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
				dx = (x + 0.5 - cx) / rx
				dy = (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0 - ragged * rng.random():
					self.put(x, y, self.shade(x, y, palette, lift))

	def drip(self, rng, x, y, length, color, tip):
		"""A one pixel wide run down the tile, ending in a darker drop."""
		for step in range(length):
			if (x, y + step) not in self.surface:
				return
			self.put(x, y + step, tip if step == length - 1 else color)

	def random_surface(self, rng, where=None):
		pool = sorted(where if where is not None else self.surface)
		return pool[rng.randrange(len(pool))] if pool else None

	def top_band(self):
		"""Upper surface pixels of every column: where moss settles and drips start on walls and holes."""
		tops = set()
		for x in range(CELL):
			column = sorted(y for (px, y) in self.surface if px == x)
			tops.update((x, y) for y in column[:2])
		return tops

	def apply(self, out):
		for (x, y), color in self.paint.items():
			alpha = self.rows[self.oy + y][self.ox + x][3]
			out[self.oy + y][self.ox + x] = color + (alpha,)


def mossy(cell, rng, kind):
	# moss creeping along the grout lines
	for x, y in cell.grout:
		if rng.random() < (0.45 if kind == 'floor' else 0.2):
			cell.put(x, y, MOSS[0])
	# clumps on the tile faces
	clumps = {'floor': (3, 5), 'wall': (2, 3), 'hole': (2, 3)}[kind]
	for _ in range(rng.randint(*clumps)):
		spot = cell.random_surface(rng, cell.top_band() if kind != 'floor' else None)
		if spot is None:
			return
		radius = rng.uniform(2.5, 5.0)
		cell.blob(rng, spot[0], spot[1], radius, radius / 2, MOSS, lift=rng.randint(0, 1))
		# lighter tufts on top of the clump
		for _ in range(3):
			cell.put(spot[0] + rng.randint(-2, 2), spot[1] + rng.randint(-1, 0), MOSS[3])
	if kind == 'floor':
		# the odd glossy slime puddle
		if rng.random() < 0.65:
			spot = cell.random_surface(rng)
			cell.blob(rng, spot[0], spot[1], rng.uniform(2.0, 3.5), 1.4, SLIME, ragged=0.2)
			cell.put(spot[0] - 1, spot[1] - 1, SLIME[2])
	else:
		# slime running down walls and over hole rims
		for _ in range(rng.randint(1, 3)):
			spot = cell.random_surface(rng, cell.top_band())
			if spot is not None:
				cell.drip(rng, spot[0], spot[1], rng.randint(3, 8), SLIME[1], SLIME[0])


def bloody(cell, rng, kind):
	splats = {'floor': (2, 3), 'wall': (1, 2), 'hole': (1, 2)}[kind]
	for _ in range(rng.randint(*splats)):
		spot = cell.random_surface(rng)
		radius = rng.uniform(2.5, 4.5)
		cell.blob(rng, spot[0], spot[1], radius, radius / 2, BLOOD, ragged=0.4, lift=rng.randint(0, 1))
		# droplets thrown out around the splat
		for _ in range(rng.randint(1, 3)):
			cell.put(spot[0] + rng.randint(-6, 6), spot[1] + rng.randint(-3, 3), BLOOD[1])
	if kind == 'floor' and rng.random() < 0.4:
		# a smear dragged across the floor along the isometric axis
		x, y = cell.random_surface(rng)
		direction = rng.choice((1, -1))
		for step in range(rng.randint(5, 10)):
			cell.put(x + 2 * step * direction, y + step, cell.shade(x, y, BLOOD, 1))
			cell.put(x + 2 * step * direction + 1, y + step, cell.shade(x, y, BLOOD, 0))
	if kind != 'floor':
		for _ in range(rng.randint(1, 3)):
			spot = cell.random_surface(rng, cell.top_band())
			if spot is not None:
				cell.drip(rng, spot[0], spot[1], rng.randint(3, 9), BLOOD[2], BLOOD[0])
	if kind == 'wall' and rng.random() < 0.25:
		# a smeared handprint: palm and four fingers
		spot = cell.random_surface(rng)
		x, y = spot
		for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, -2), (0, -2), (1, -2), (2, -2), (-1, -3), (1, -3)):
			cell.put(x + dx, y + dy, BLOOD[2])


def make_variant(rows, name, kind, variant, painter):
	out = [row[:] for row in rows]
	for cy in range(len(rows) // CELL):
		for cx in range(len(rows[0]) // CELL):
			cell = Cell(rows, cx, cy)
			if cell.empty():
				continue
			seed = (sum(map(ord, name + variant)) * 7919 + cy * 131 + cx) & 0xFFFFFFFF
			painter(cell, random.Random(seed), kind)
			cell.apply(out)
	return out


def main():
	for name, kind in ATLASES:
		rows = read_png(os.path.join(TILESETS, name + '.png'))
		write_png(os.path.join(TILESETS, name + '_mossy.png'), make_variant(rows, name, kind, 'mossy', mossy))
		write_png(os.path.join(TILESETS, name + '_bloody.png'), make_variant(rows, name, kind, 'bloody', bloody))


if __name__ == '__main__':
	main()
