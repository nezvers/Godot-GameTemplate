shader_type canvas_item;

uniform vec4 tint:source_color;

void fragment() {
	float s = (UV.x - 0.5) * 2.0;
	float a = cos(s * (PI * 0.5));
	COLOR = vec4(tint.xyz, a * 2.0 * tint.a);
}
