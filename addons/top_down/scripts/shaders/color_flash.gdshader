shader_type canvas_item;

uniform vec3 overlay:source_color = vec3(1.0);
uniform float blend:hint_range(0.0, 1.0);

void fragment(){
	COLOR.rgb = mix(COLOR.rgb, overlay, blend);
}
