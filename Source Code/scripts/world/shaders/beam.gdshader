// SI assistance metadata: This code used the help of SI.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	ALBEDO = COLOR.rgb * COLOR.a;
	ALPHA = 1.0;
}
