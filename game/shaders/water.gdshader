shader_type spatial;
render_mode cull_disabled, depth_draw_always, unshaded;
// Energy river: dark glassy water with a scrolling neon grid, pulse lines
// running towards you and glowing banks.

uniform vec4 deep_color : source_color = vec4(0.04, 0.02, 0.19, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.06, 0.44, 1.0);
uniform vec4 grid_color : source_color = vec4(1.0, 0.18, 0.82, 1.0);
uniform vec4 edge_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float alpha = 0.88;

varying float v_wave;
varying vec3 v_world;

float waves(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 2.0) * 0.05
		+ sin(p.y * 0.55 - t * 1.7) * 0.07
		+ sin((p.x + p.y) * 1.7 + t * 3.1) * 0.02;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float y = waves(w.xz, TIME);
	VERTEX.y += y;
	v_wave = y;
	v_world = w;
}

float grid_line(float v, float width) {
	float f = abs(fract(v) - 0.5);
	return smoothstep(0.5 - width, 0.5, f);
}

void fragment() {
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(25.0, 95.0, dist);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, clamp(0.5 + v_wave * 5.0, 0.0, 1.0));
	// grid: 1 m cells across, 2 m along the river
	float gx = grid_line(v_world.x * 0.5, 0.04);
	float gz = grid_line(v_world.z * 0.25, 0.03);
	float grid = max(gx, gz) * fade;
	// pulses racing along the river
	float pulse = smoothstep(0.96, 1.0, sin(v_world.z * 0.35 - TIME * 6.0)) * 0.8 * fade;
	float edge = smoothstep(3.3, 4.9, abs(v_world.x));
	vec3 col = base + grid_color.rgb * grid * 0.9 + grid_color.rgb * pulse * 0.4 + edge_color.rgb * edge * 1.2;
	vec2 cell = floor(v_world.xz * 3.0) + floor(TIME * 2.0);
	float sparkle = step(0.992, fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453)) * 0.6;
	ALBEDO = col + vec3(sparkle);
	ALPHA = clamp(alpha + grid * 0.1 + edge * 0.1, 0.0, 1.0);
}
