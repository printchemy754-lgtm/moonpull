shader_type spatial;
render_mode cull_disabled;
// Track floor: a solid, bright colour with a squiggly "maze" pattern
// (UV = (s, d) in metres), cartoon style.

uniform vec4 base_color : source_color = vec4(0.25, 0.49, 1.0, 1.0);
uniform vec4 grid_color : source_color = vec4(0.18, 0.38, 0.88, 1.0);   // pattern colour
uniform vec4 lane_color : source_color = vec4(0.6, 0.3, 1.0, 1.0);      // centre accent

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float n = noise(v_uv * 0.9) * 0.65 + noise(v_uv * 1.9) * 0.35;
	float squig = 1.0 - smoothstep(0.03, 0.07, abs(fract(n * 5.0) - 0.5));
	vec3 c = mix(base_color.rgb, grid_color.rgb, squig * 0.85);
	float across = 1.0 - smoothstep(0.0, 0.06, abs(fract(v_uv.y * 0.125) - 0.5) - 0.44);
	c = mix(c, base_color.rgb * 1.12, across * 0.25);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	METALLIC = 0.0;
	EMISSION = vec3(0.0);
}
