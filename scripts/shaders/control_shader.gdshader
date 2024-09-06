shader_type canvas_item;

uniform vec2 size = vec2(217,55);// required to provide
uniform float scale = 1.0;
uniform float rotation = 0.0;
uniform vec2 skew = vec2(0.0, 0.0);
uniform vec2 offset = vec2(0.0, 0.0);
uniform vec2 stretch = vec2(1.0, 1.0);
uniform vec4 overlay: source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform sampler2D mask_texture: source_color;
uniform float mask_blend: hint_range(0.0, 1.0) = 0.0;
uniform float saturation = 1.0;
uniform vec3 hsv = vec3(0.0);

uniform vec4 shine_color : source_color = vec4(1.0);
uniform float shine_progress : hint_range(0.0, 1.0) = 0.0;
uniform float shine_size : hint_range(0.0, 1.0) = 0.1;
uniform float shine_angle : hint_range(0.0, 89.9) = 45.0;

varying vec4 MODULATE; // seems to be a removed built-in variable from 3.x. Now it is baked in fragment color.
void vertex(){
	vec2 half_size = size * 0.5;
	vec2 skew_offset = skew * -(UV.yx - vec2(0.5, 0.5)) * 2.0;
	vec2 from_center = VERTEX - half_size + skew_offset;
	float len = length(from_center);
	float angle = atan(from_center.y, from_center.x);
	angle = (angle + radians(rotation));
	from_center.x = cos(angle) * len;
	from_center.y = sin(angle) * len;
	
	VERTEX = scale * from_center * stretch + half_size + offset;
	MODULATE = COLOR; // store modulate value
}

// https://godotshaders.com/shader/desaturation-shader/
vec3 saturated_color(vec3 color, float saturation_value){
	return mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, max(saturation_value, 0.0));
}

vec3 saturation_average(vec3 color, float saturation_value){
	float gray = (color.r + color.g + color.b) / 3.0;
	return mix(vec3(gray), color, saturation_value);
}

float map_value(float value, float inMin, float inMax, float outMin, float outMax) {
    return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
}

// https://godotshaders.com/shader/2d-controlled-shine-highlight-with-angle-adjustment
vec3 shine(vec3 color, vec2 uv){
	float slope = tan(radians(shine_angle));
	float progress = map_value(shine_progress, 0.0, 1.0, -1.0 - shine_size - shine_size * slope, 1.0 * slope);
	float shine = step(slope * uv.x - uv.y, progress + shine_size + shine_size * slope) - step(slope * uv.x - uv.y, progress);
	return  mix(color.rgb, shine_color.rgb, shine * shine_color.a);
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// https://godotshaders.com/shader/hsv-adjustment/
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 hsv_shift(vec3 color){
	vec3 hsv_from_rgb = rgb2hsv(color) + hsv;
	hsv_from_rgb.g = clamp(hsv_from_rgb.g, 0.0, 1.0);
	hsv_from_rgb.b = clamp(hsv_from_rgb.b, 0.0, 1.0);
	return hsv2rgb(hsv_from_rgb);
}

float mask_fade(float alpha, vec2 uv){
	return alpha * texture(mask_texture, uv).a;
}

void fragment(){
	COLOR.rgb = hsv_shift(COLOR.rgb);					// HSV
	COLOR.rgb = saturated_color(COLOR.rgb, saturation);	// Saturation
	COLOR.rgb = mix(COLOR.rgb, overlay.rgb, overlay.a);	// Overlay
	COLOR.rgb = shine(COLOR.rgb, UV);					// Shine
	COLOR.a = mask_fade(COLOR.a, UV);
}


