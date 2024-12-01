shader_type canvas_item;

// 1D texture gradient from center for generated circle;
uniform sampler2D gradient:source_color;
uniform float radius:hint_range(0.0, 0.70710678118) = 0.5;

const vec2 CENTER = vec2(0.5, 0.5);

void fragment() {
	float _distance = length(UV - CENTER);
	float _mask = step(_distance, radius);
	vec4 _modulate = COLOR;
	vec4 _gradient_sample = texture(gradient, vec2(radius - _distance, 0.0));
	COLOR = _gradient_sample * _modulate * _mask;
}

