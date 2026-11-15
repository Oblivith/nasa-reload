// Code generated with AI assistance (Claude). Reviewed by team.
// Additive haze for fake volumetric light: sun shafts from windows and the cones under
// the Design Bay work lights. Vertex colour is the light colour, vertex alpha its strength.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	ALBEDO = COLOR.rgb * COLOR.a;
	ALPHA = 1.0;
}
