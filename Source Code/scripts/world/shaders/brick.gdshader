// SI assistance metadata: This code used the help of SI.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

#include "plastic.gdshaderinc"

uniform float rough = 0.2;
uniform float saturation = 1.08;

float grain(vec2 p) {
	return fract(sin(dot(floor(p * 72.0), vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 c = plastic_saturate(pow(COLOR.rgb, vec3(2.2)), saturation);
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = n;
	ALBEDO = c;
	float plastic_grain = grain(VERTEX.xy + VERTEX.xz);
	ALBEDO *= 0.994 + plastic_grain * 0.014;
	ROUGHNESS = clamp(rough + (plastic_grain - 0.5) * 0.02, 0.06, 0.92);
	SPECULAR = 0.56;
	vec3 n_w = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 v_w = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	EMISSION = plastic_sheen(n_w, v_w, 1.0 - rough);
}
