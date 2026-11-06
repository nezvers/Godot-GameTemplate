#!/usr/bin/env python3
"""Pixel-art generator for the home base: memory-grid pistons, levers, the write
button, short-circuit sparks, the water gun and the puddles shot by puddle guns.

Reuses the helpers of ../generate_enemy_sprites.py (standard library only):

    python3 generate_home_sprites.py

Output layout:
- misc/piston_strip4.png           32x32 frames, same geometry as block_strip4.png (lowered -> raised)
- misc/piston_wet_strip4.png       wet sheen overlay matching each piston frame
- misc/piston_select_strip4.png    lane-select glow overlay matching each piston frame
- vfx/spark_32x32_strip6.png       short-circuit sparks drawn over a piston
- misc/lever_16x24_strip2.png      off / on
- misc/write_button_24x24_strip2.png  idle / pressed
- misc/reset_button_24x24_strip2.png  idle / pressed (blue)
- misc/gate_lever_16x24_strip6.png  dial pointing at AND, OR, XOR, NAND, NOR, XNOR
- misc/water_puddle_24x16.png, player_acid_puddle_24x16.png, blood_puddle_24x16.png
- projectile/water_shot_8x8.png
- weapon/water_gun_0.png
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IMAGES = os.path.dirname(HERE)
sys.path.insert(0, IMAGES)

from generate_enemy_sprites import ellipse, new_canvas, put, thick_line, write_png, write_strip  # noqa: E402

COLORS = {
	'top': (168, 178, 190, 255),      # brushed steel top
	'top_hi': (210, 220, 228, 255),
	'left': (104, 112, 128, 255),     # lit side
	'right': (70, 76, 92, 255),       # shaded side
	'rim': (44, 48, 60, 255),
	'plate': (92, 98, 112, 255),      # lowered floor plate
	'bolt': (54, 58, 70, 255),
	'stripe': (232, 178, 52, 255),    # hazard yellow
	'water': (120, 200, 255, 150),
	'water_hi': (220, 244, 255, 210),
	'drip': (96, 170, 240, 200),
	'select': (255, 236, 120, 110),
	'select_edge': (255, 244, 170, 200),
	'spark': (255, 250, 200, 255),
	'spark_blue': (140, 220, 255, 255),
	'spark_core': (255, 255, 255, 255),
	'wood': (120, 84, 52, 255),
	'metal': (130, 136, 150, 255),
	'metal_dark': (70, 76, 92, 255),
	'knob': (40, 40, 48, 255),
	'lamp_off': (120, 40, 40, 255),
	'lamp_on': (110, 240, 110, 255),
	'button': (220, 52, 46, 255),
	'button_hi': (255, 130, 110, 255),
	'button_dark': (140, 24, 30, 255),
	'reset': (60, 130, 230, 255),
	'reset_hi': (150, 200, 255, 255),
	'reset_dark': (30, 70, 150, 255),
	'dial': (40, 44, 56, 255),
	'dial_rim': (150, 156, 170, 255),
	'needle': (255, 210, 70, 255),
}

FRAME = 32
## Height the top lifts per frame; block_strip4 rises 14px.
HEIGHTS = [0, 5, 10, 14]
## Ground diamond centre of a 32x32 frame (BlockWall sprite sits 1px up).
GROUND_Y = 23


def in_diamond(x, y, cx, cy, half_w=16.0, half_h=8.0):
	return abs(x + 0.5 - cx) / half_w + abs(y + 0.5 - cy) / half_h <= 1.0


def piston_frame(height):
	canvas = new_canvas(FRAME, FRAME)
	top_y = GROUND_Y - height
	# Sides: every column between the top diamond's lower edge and the ground diamond's lower edge.
	for x in range(FRAME):
		dx = abs(x + 0.5 - 16)
		if dx > 16:
			continue
		edge = 8.0 * (1.0 - dx / 16.0)
		for y in range(FRAME):
			if top_y <= y + 0.5 <= GROUND_Y + edge and y + 0.5 >= top_y + edge - 0.5:
				canvas[y][x] = COLORS['left'] if x < 16 else COLORS['right']
	# Hazard stripes on the sides once lifted.
	if height >= 5:
		for x in range(FRAME):
			for y in range(FRAME):
				if canvas[y][x] in (COLORS['left'], COLORS['right']) and (x + y) % 6 < 2 and y > top_y + 4:
					canvas[y][x] = COLORS['stripe']
	# Top face.
	for y in range(FRAME):
		for x in range(FRAME):
			if in_diamond(x, y, 16, top_y):
				canvas[y][x] = COLORS['top'] if height > 0 else COLORS['plate']
			if in_diamond(x, y, 16, top_y) and not in_diamond(x, y, 16, top_y, 14.5, 7.0):
				canvas[y][x] = COLORS['rim']
	# Highlight streak and bolts.
	if height > 0:
		for i in range(6):
			put(canvas, 10 + i, top_y - 2 + i * 0.5, COLORS['top_hi'])
	for bx, by in ((16, top_y - 5), (7, top_y), (25, top_y), (16, top_y + 5)):
		put(canvas, bx, by, COLORS['bolt'])
	return canvas


def piston_overlay_frame(height, fill, edge, drips=False):
	"""Covers the same pixels as piston_frame(height) with a translucent tint."""
	base = piston_frame(height)
	canvas = new_canvas(FRAME, FRAME)
	top_y = GROUND_Y - height
	for y in range(FRAME):
		for x in range(FRAME):
			if base[y][x] is None:
				continue
			if in_diamond(x, y, 16, top_y):
				canvas[y][x] = fill
				if not in_diamond(x, y, 16, top_y, 14.5, 7.0):
					canvas[y][x] = edge
			elif drips and (x % 5 == 2):
				canvas[y][x] = COLORS['drip']
	if drips:
		ellipse(canvas, 11, top_y - 1, 2.0, 1.0, COLORS['water_hi'])
		ellipse(canvas, 20, top_y + 2, 1.2, 0.7, COLORS['water_hi'])
	return canvas


def spark_frames():
	"""Six frames of zigzag arcs crawling over a raised piston top, then fading."""
	rng = random.Random(7)
	frames = []
	for frame in range(6):
		canvas = new_canvas(FRAME, FRAME)
		arcs = 4 if frame < 4 else 1
		if frame < 2:
			ellipse(canvas, 16, 10, 7.0 - frame * 2, 3.5 - frame, (180, 230, 255, 120))
		for _ in range(arcs):
			x = rng.uniform(8, 24)
			y = rng.uniform(5, 18)
			color = COLORS['spark'] if rng.random() < 0.6 else COLORS['spark_blue']
			for _step in range(5):
				nx = x + rng.uniform(-5, 5)
				ny = y + rng.uniform(-4, 3)
				thick_line(canvas, x, y, nx, ny, 1.4, color)
				x, y = nx, ny
		if frame < 3:
			for _ in range(4):
				put(canvas, rng.uniform(4, 28), rng.uniform(4, 28), COLORS['spark_core'])
		frames.append(canvas)
	return frames


def lever_frame(on):
	canvas = new_canvas(16, 24)
	# Base box.
	for y in range(16, 23):
		for x in range(3, 13):
			canvas[y][x] = COLORS['metal_dark'] if y > 19 else COLORS['metal']
	# Lamp.
	ellipse(canvas, 8, 18, 1.6, 1.6, COLORS['lamp_on'] if on else COLORS['lamp_off'])
	# Handle tilted to the right when on.
	tip_x = 12 if on else 4
	thick_line(canvas, 8, 16, tip_x, 6, 1.5, COLORS['wood'])
	ellipse(canvas, tip_x, 5, 2.0, 2.0, COLORS['knob'])
	return canvas


def write_button_frame(pressed, body='button', highlight='button_hi', dark='button_dark'):
	canvas = new_canvas(24, 24)
	for y in range(14, 23):
		for x in range(4, 20):
			canvas[y][x] = COLORS['metal_dark'] if y > 18 else COLORS['metal']
	for x in range(4, 20, 4):
		canvas[18][x] = COLORS['stripe']
		canvas[18][x + 1] = COLORS['stripe']
	top = 12 if pressed else 9
	ellipse(canvas, 12, top + 3, 6.0, 3.0, COLORS[dark])
	ellipse(canvas, 12, top + 1.5, 6.0, 3.0, COLORS[body])
	ellipse(canvas, 10, top + 0.5, 2.0, 1.0, COLORS[highlight])
	return canvas


def gate_lever_frame(position, count=6):
	"""A rotary switch on a post: the needle sweeps a half circle, one stop per gate."""
	canvas = new_canvas(16, 24)
	for y in range(16, 23):
		for x in range(3, 13):
			canvas[y][x] = COLORS['metal_dark'] if y > 19 else COLORS['metal']
	thick_line(canvas, 8, 16, 8, 12, 2.0, COLORS['metal_dark'])
	ellipse(canvas, 8, 8, 7.0, 7.0, COLORS['dial_rim'])
	ellipse(canvas, 8, 8, 5.8, 5.8, COLORS['dial'])
	# stop marks from left (AND) over the top to right (XNOR)
	for i in range(count):
		angle = math.pi + math.pi * i / (count - 1)
		put(canvas, 8 + 5.0 * math.cos(angle), 8 + 5.0 * math.sin(angle), COLORS['dial_rim'])
	angle = math.pi + math.pi * position / (count - 1)
	thick_line(canvas, 8, 8, 8 + 4.5 * math.cos(angle), 8 + 4.5 * math.sin(angle), 1.2, COLORS['needle'])
	put(canvas, 8, 8, COLORS['knob'])
	lamp = COLORS['lamp_on']
	ellipse(canvas, 8, 18, 1.6, 1.6, lamp)
	return canvas


def puddle_frame(rim, body, highlight):
	canvas = new_canvas(24, 16)
	ellipse(canvas, 12, 8, 11.5, 7.0, rim)
	ellipse(canvas, 12, 8, 10.0, 5.8, body)
	ellipse(canvas, 8, 6, 2.0, 1.0, highlight)
	ellipse(canvas, 16, 10, 1.0, 0.7, highlight)
	return canvas


def water_shot():
	canvas = new_canvas(8, 8)
	ellipse(canvas, 4, 4, 3.0, 3.0, (60, 140, 230, 255))
	ellipse(canvas, 4, 4, 2.2, 2.2, (120, 200, 255, 255))
	put(canvas, 3, 3, (230, 248, 255, 255))
	return canvas


def water_gun():
	"""Same scale and grip spot as gun_0.png: a squirt gun with a tank on top."""
	canvas = new_canvas(16, 16)
	body = (236, 120, 40, 255)
	body_dark = (170, 70, 24, 255)
	for x in range(5, 12):
		canvas[7][x] = body
	canvas[7][12] = (72, 139, 212, 255)
	canvas[8][5] = body_dark
	canvas[8][6] = body_dark
	canvas[9][5] = body_dark
	canvas[9][6] = body_dark
	# Tank.
	for x in range(7, 10):
		canvas[5][x] = (120, 215, 255, 255)
		canvas[6][x] = (72, 139, 212, 255)
	return canvas


def main():
	misc = HERE
	write_strip(os.path.join(misc, 'piston_strip4.png'), [piston_frame(h) for h in HEIGHTS])
	write_strip(
		os.path.join(misc, 'piston_wet_strip4.png'),
		[piston_overlay_frame(h, COLORS['water'], COLORS['water_hi'], drips=True) for h in HEIGHTS],
	)
	write_strip(
		os.path.join(misc, 'piston_select_strip4.png'),
		[piston_overlay_frame(h, COLORS['select'], COLORS['select_edge']) for h in HEIGHTS],
	)
	write_strip(os.path.join(IMAGES, 'vfx', 'spark_32x32_strip6.png'), spark_frames())
	write_strip(os.path.join(misc, 'lever_16x24_strip2.png'), [lever_frame(False), lever_frame(True)])
	write_strip(os.path.join(misc, 'write_button_24x24_strip2.png'), [write_button_frame(False), write_button_frame(True)])
	write_strip(
		os.path.join(misc, 'reset_button_24x24_strip2.png'),
		[write_button_frame(p, 'reset', 'reset_hi', 'reset_dark') for p in (False, True)],
	)
	write_strip(os.path.join(misc, 'gate_lever_16x24_strip6.png'), [gate_lever_frame(i) for i in range(6)])

	write_png(os.path.join(misc, 'water_puddle_24x16.png'), puddle_frame((70, 150, 220, 170), (130, 205, 250, 140), (230, 248, 255, 220)))
	write_png(os.path.join(misc, 'player_acid_puddle_24x16.png'), puddle_frame((70, 130, 20, 255), (150, 220, 50, 255), (220, 255, 140, 255)))
	write_png(os.path.join(misc, 'blood_puddle_24x16.png'), puddle_frame((90, 10, 20, 255), (160, 22, 34, 255), (230, 90, 90, 255)))

	write_png(os.path.join(IMAGES, 'projectile', 'water_shot_8x8.png'), water_shot())
	write_png(os.path.join(IMAGES, 'weapon', 'water_gun_0.png'), water_gun())


if __name__ == '__main__':
	main()
