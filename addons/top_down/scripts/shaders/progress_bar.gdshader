shader_type canvas_item;

uniform float progress_foreground:hint_range(0.0, 1.0) = 1.0;
uniform float progress_middle:hint_range(0.0, 1.0) = 1.0;
uniform vec3 background:source_color;
uniform vec3 midle:source_color;
uniform vec3 foreground:source_color;

uniform float smoothing:hint_range(0.0, 1.0) = 0.001;


void fragment() {
	vec3 color_middle = mix(midle, background, smoothstep(progress_middle, progress_middle+smoothing, UV.x));
	COLOR.rgb = mix(foreground, color_middle, smoothstep(progress_foreground, progress_foreground+smoothing, UV.x));
}
