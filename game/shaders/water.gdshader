shader_type spatial;
render_mode cull_disabled, depth_draw_always;

// Futuristic "energy river": glossy liquid + glowing grid + pulse lines.
uniform vec4 deep_color : source_color = vec4(0.04, 0.04, 0.25, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.23, 0.69, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.18, 0.82, 1.0);
uniform float alpha = 0.86;
uniform float grid_size = 2.0;

varying float v_wave;
varying vec3 v_world;

float waves(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 2.0) * 0.05
		+ sin(p.y * 0.55 - t * 1.7) * 0.08
		+ sin((p.x + p.y) * 1.7 + t * 3.1) * 0.02;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float y = waves(w.xz, TIME);
	float e = 0.15;
	float dx = (waves(w.xz + vec2(e, 0.0), TIME) - y) / e;
	float dz = (waves(w.xz + vec2(0.0, e), TIME) - y) / e;
	VERTEX.y += y;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
	v_wave = y;
	v_world = w;
}

float grid_line(float coord, float width) {
	float f = abs(fract(coord) - 0.5);
	return smoothstep(0.5 - width, 0.5, f);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec2 g = v_world.xz / grid_size + vec2(0.0, v_wave * 0.6);
	float grid = max(grid_line(g.x, 0.035), grid_line(g.y, 0.035));
	// pulses that run down the river
	float pulse = smoothstep(0.92, 1.0, sin(v_world.z * 0.35 - TIME * 3.0)) * grid_line(g.x, 0.08);
	float dist = length(v_world.xz - CAMERA_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(25.0, 70.0, dist);
	float edge = smoothstep(3.4, 4.9, abs(v_world.x));
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, clamp(0.45 + v_wave * 4.0 + fres * 0.5, 0.0, 1.0));
	ALBEDO = base;
	EMISSION = grid_color.rgb * (grid * 0.9 + pulse * 2.0) * fade + edge_color.rgb * edge * 1.4;
	ROUGHNESS = 0.05;
	METALLIC = 0.2;
	SPECULAR = 0.9;
	ALPHA = mix(alpha, 1.0, fres);
}
