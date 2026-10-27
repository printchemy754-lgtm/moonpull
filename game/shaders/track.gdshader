shader_type spatial;
render_mode cull_disabled;
// Track floor: dark glossy panels with a neon grid (UV = (s, d) in metres)
// and light pulses racing forward.

uniform vec4 base_color : source_color = vec4(0.07, 0.06, 0.17, 1.0);
uniform vec4 grid_color : source_color = vec4(1.0, 0.18, 0.82, 1.0);
uniform vec4 lane_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

float line(float v, float w) {
	return smoothstep(0.5 - w, 0.5, abs(fract(v) - 0.5));
}

void fragment() {
	float across = line(v_uv.y * 0.25, 0.035);          // a line every 4 m
	float along = line(v_uv.x * 0.5 + 0.5, 0.03);       // lanes every 2 m
	float centre = 1.0 - smoothstep(0.03, 0.08, abs(v_uv.x));
	float pulse = smoothstep(0.97, 1.0, sin(v_uv.y * 0.3 - TIME * 5.0));
	ALBEDO = base_color.rgb;
	METALLIC = 0.1;
	ROUGHNESS = 0.65;
	EMISSION = grid_color.rgb * (across * 0.9 + pulse * 0.5) + lane_color.rgb * (along * 0.35 + centre * 0.25);
}
