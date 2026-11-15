// Code generated with AI assistance (Claude). Reviewed by team.
// Unshaded emissive surface: light panels, CRT screens, indicator lamps. Vertex colour is
// the lamp colour. With `blink` on, each lamp flashes on its own from UV (x = seed,
// y = flashes per second), so thousands of panel lights cost no script time at all.
shader_type spatial;
render_mode unshaded, cull_back;

uniform float energy = 1.6;
uniform bool blink = false;
uniform bool scanlines = false;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2)) * energy;
	if (blink) {
		float on = step(0.45, hash(vec2(UV.x, floor(TIME * UV.y + UV.x * 13.0))));
		c *= mix(0.07, 1.0, on);
	}
	if (scanlines) {
		c *= 0.82 + 0.18 * sin(wpos.y * 260.0);
		c *= 0.94 + 0.06 * sin(TIME * 50.0 + wpos.x * 3.0);
	}
	ALBEDO = c;
}
