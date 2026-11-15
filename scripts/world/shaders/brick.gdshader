// Code generated with AI assistance (Claude). Reviewed by team.
// Glossy ABS plastic for BrickKit's studded bricks (rockets, station scenery). The colour
// comes from each brick instance; the shine from lights plus the fake studio reflection.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

#include "plastic.gdshaderinc"

uniform float rough = 0.2;
uniform float saturation = 1.22;

void fragment() {
	vec3 c = plastic_saturate(pow(COLOR.rgb, vec3(2.2)), saturation);
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = n;
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.72;
	vec3 n_w = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 v_w = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	EMISSION = plastic_sheen(n_w, v_w, 1.0 - rough);
}
