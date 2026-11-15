// Code generated with AI assistance (Claude). Reviewed by team.
// Shared toy-plastic helpers: injection-moulded ABS reads as plastic because of three
// things: saturated colour, a soft rounded edge that catches a highlight, and a clear
// glossy coat that mirrors the room. The Web renderer has no reflection probes, so the
// "room" is a tiny analytic studio (warm ceiling, softbox, dark floor) added as emission.

// Global strength of the fake studio reflection; the atmosphere follows room brightness.
uniform float sheen = 1.0;

vec3 plastic_saturate(vec3 c, float amount) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return max(mix(vec3(l), c, amount), vec3(0.0));
}

// Rounded-edge normal for a flat face. `fpos` is the position on the face in metres from
// its centre, `half_size` the face half extents, `width` the bevel width. Returns the
// tilt along the face's two axes (x, y in -1..1), zero in the middle of the face.
vec2 plastic_bevel(vec2 fpos, vec2 half_size, float width) {
	if (half_size.x <= 0.0 || half_size.y <= 0.0) {
		return vec2(0.0);
	}
	float w = min(width, 0.6 * min(half_size.x, half_size.y));
	vec2 d = half_size - abs(fpos);
	vec2 t = 1.0 - smoothstep(vec2(0.0), vec2(w), d);
	return t * t * sign(fpos);
}

// Clear-coat reflection of a studio: returns emission to add. n and v in world space.
vec3 plastic_sheen(vec3 n, vec3 v, float gloss) {
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	float fres = 0.045 + 0.55 * pow(1.0 - ndv, 4.0);
	vec3 r = reflect(-v, n);
	vec3 room = mix(vec3(0.20, 0.15, 0.11), vec3(1.0, 0.94, 0.84), smoothstep(-0.25, 0.55, r.y));
	// Two softboxes: a big one overhead and a key from the window side.
	float box = pow(max(dot(r, normalize(vec3(0.35, 0.80, 0.48))), 0.0), mix(12.0, 90.0, gloss));
	box += 0.6 * pow(max(dot(r, normalize(vec3(-0.55, 0.62, -0.30))), 0.0), mix(10.0, 60.0, gloss));
	return (room * fres * 0.55 + vec3(1.0, 0.97, 0.9) * box * (0.10 + 0.25 * gloss)) * sheen * gloss;
}
