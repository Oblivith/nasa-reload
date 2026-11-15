// Code generated with AI assistance (Claude). Reviewed by team.
// One lit material for every opaque surface, made to look like glossy ABS toy plastic.
// Colour comes from vertex colours (so a whole room is one draw call). Everything else is
// procedural, so no textures are needed and it stays cheap on the Web renderer:
//   - every box face gets a soft rounded edge (normal trick) that catches a highlight;
//   - big walls are split into toy bricks (courses 0.48 m, a running bond of 1x4 bricks);
//   - cylinder rims (the real studs on floors and furniture are small cylinders) are
//     rounded the same way;
//   - a clear-coat "studio" reflection (plastic.gdshaderinc).
// BrickMesh supplies UV = position on the face (m), UV2 = face half size, and tangents.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

#include "plastic.gdshaderinc"

uniform int pattern = 0;        // 0 plain, 1 checker plates, 2 ceiling grid, 3 slabs, 4 soft, 5 planks
uniform float scale = 0.8;      // plate size in metres
uniform float rough = 0.3;
uniform float metal = 0.0;
uniform float stud_pitch = 0.4;   // real studs are geometry (BrickMesh); this sizes the wall bricks
uniform float bevel = 0.022;
uniform float saturation = 1.22;

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
	vec3 c = plastic_saturate(pow(COLOR.rgb, vec3(2.2)), saturation);
	vec2 p = abs(wnrm.y) > 0.5 ? wpos.xz : (abs(wnrm.x) > 0.5 ? wpos.zy : wpos.xy);
	vec2 fpos = UV;
	vec2 half_size = UV2;
	float dist = length(VERTEX);
	float r = rough;
	vec2 tilt = plastic_bevel(fpos, half_size, bevel);
	float edge = max(abs(tilt.x), abs(tilt.y));
	float shade = 1.0;

	if (pattern == 1) {
		vec2 t = floor(p / scale);
		shade *= mix(0.84, 1.0, mod(t.x + t.y, 2.0));
		vec2 f = abs(fract(p / scale) - 0.5) * scale;      // distance from the plate centre
		vec2 g = 1.0 - smoothstep(0.0, 0.02, scale * 0.5 - f);
		shade *= 1.0 - 0.3 * max(g.x, g.y);
	} else if (pattern == 2) {
		vec2 f = fract(p / scale);
		shade *= 1.0 - 0.16 * max(step(f.x, 0.03), step(f.y, 0.03));
		shade *= 0.97 + 0.03 * hash(floor(p / scale));
	} else if (pattern == 3) {
		vec2 f = abs(fract(p / scale) - 0.5) * scale;
		vec2 g = 1.0 - smoothstep(0.0, 0.02, scale * 0.5 - f);
		shade *= 1.0 - 0.3 * max(g.x, g.y);
		shade *= 0.95 + 0.05 * hash(floor(p / scale));
	} else if (pattern == 4) {
		shade *= 0.96 + 0.04 * hash(floor(p / (stud_pitch * 2.0)));
	} else if (pattern == 5) {
		vec2 q = vec2(p.x / (scale * 6.0), p.y / scale);
		q.x += 0.5 * mod(floor(q.y), 2.0);
		vec2 f = fract(q);
		shade *= 0.92 + 0.08 * hash(floor(q));
		shade *= 1.0 - 0.22 * max(step(f.x, 0.012), step(f.y, 0.06));
	}

	// Brick courses on big upright faces (walls): seams with a rounded lip.
	if (abs(wnrm.y) < 0.5 && pattern == 0 && half_size.x > 0.7 && half_size.y > 0.4) {
		float course_h = stud_pitch * 1.2;
		float brick_l = stud_pitch * 4.0;
		float row = floor(wpos.y / course_h);
		float along = abs(wnrm.x) > 0.5 ? wpos.z : wpos.x;
		float u = along / brick_l + 0.5 * mod(row, 2.0);
		float dy = (0.5 - abs(fract(wpos.y / course_h) - 0.5)) * course_h;
		float dx = (0.5 - abs(fract(u) - 0.5)) * brick_l;
		float fade = 1.0 - smoothstep(22.0, 40.0, dist);
		float seam = 1.0 - smoothstep(0.0, 0.016, min(dx, dy));
		shade *= 1.0 - 0.34 * seam * fade;
		shade *= 0.965 + 0.07 * hash(vec2(floor(u), row));
		// Lip: tilt the normal away from the seam on both sides of it.
		float sy = sign(fract(wpos.y / course_h) - 0.5);
		float lip = (1.0 - smoothstep(0.0, 0.05, dy)) * fade;
		tilt.y += sy * lip * 0.8;
		edge = max(edge, lip * 0.6);
	}

	c *= shade * (1.0 + 0.16 * edge);
	vec3 n = normalize(NORMAL + (TANGENT * tilt.x + BINORMAL * tilt.y) * 0.85);
	NORMAL = n;
	ALBEDO = c;
	ROUGHNESS = r;
	METALLIC = metal;
	SPECULAR = 0.72;
	float gloss = clamp(1.0 - r, 0.0, 1.0);
	vec3 n_w = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 v_w = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	EMISSION = plastic_sheen(n_w, v_w, gloss) * mix(vec3(1.0), c * 2.0 + 0.2, metal);
}
