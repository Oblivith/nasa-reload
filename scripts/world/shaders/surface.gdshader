// Code generated with AI assistance (Claude). Reviewed by team.
// One lit material for every opaque placeholder surface. Colour comes from vertex colours
// (so a whole room is one draw call); `pattern` adds procedural floor/ceiling detail from
// world position, so no textures or UVs are needed. Swap for real materials with .glb art.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform int pattern = 0;        // 0 plain, 1 checker tiles, 2 grid tiles, 3 concrete, 4 carpet, 5 planks
uniform float scale = 0.6;      // tile size in metres
uniform float rough = 0.85;
uniform float metal = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	vec2 p = abs(wnrm.y) > 0.5 ? wpos.xz : (abs(wnrm.x) > 0.5 ? wpos.zy : wpos.xy);
	float r = rough;
	if (pattern == 1) {
		vec2 t = floor(p / scale);
		c *= mix(0.80, 1.0, mod(t.x + t.y, 2.0));
		vec2 f = fract(p / scale);
		c *= 1.0 - 0.18 * max(step(f.x, 0.025), step(f.y, 0.025));
	} else if (pattern == 2) {
		vec2 f = fract(p / scale);
		c *= 1.0 - 0.22 * max(step(f.x, 0.03), step(f.y, 0.03));
		c *= 0.96 + 0.04 * hash(floor(p / scale));
	} else if (pattern == 3) {
		vec2 f = fract(p / scale);
		c *= 1.0 - 0.25 * max(step(f.x, 0.008), step(f.y, 0.008));
		c *= 0.93 + 0.07 * hash(floor(p * 9.0));
	} else if (pattern == 4) {
		c *= 0.9 + 0.1 * hash(floor(p * 40.0));
	} else if (pattern == 5) {
		vec2 q = vec2(p.x / (scale * 6.0), p.y / scale);
		q.x += 0.5 * mod(floor(q.y), 2.0);
		vec2 f = fract(q);
		c *= 0.9 + 0.1 * hash(floor(q));
		c *= 1.0 - 0.2 * max(step(f.x, 0.01), step(f.y, 0.04));
	}
	ALBEDO = c;
	ROUGHNESS = r;
	METALLIC = metal;
}
