// SI assistance metadata: This code used the help of SI.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec3 tint = vec3(1.0, 0.965, 0.885);
uniform float vignette = 0.34;
uniform float grain = 0.055;

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.0, 0.82);
	float v = 1.0 - vignette * smoothstep(0.3, 0.78, length(uv));
	vec2 cell = floor(FRAGCOORD.xy / 2.0) + floor(TIME * 24.0) * 17.0;
	float n = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(tint * v * (1.0 - grain * n), 1.0);
}
