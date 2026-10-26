shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec4 deep_color : source_color = vec4(0.05, 0.28, 0.52, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.72, 0.84, 1.0);
uniform vec4 foam_color : source_color = vec4(0.94, 0.98, 1.0, 1.0);
uniform float alpha = 0.84;

varying float v_wave;
varying vec3 v_world;

float waves(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 2.0) * 0.06
		+ sin(p.y * 0.55 - t * 1.7) * 0.09
		+ sin((p.x + p.y) * 1.7 + t * 3.1) * 0.025;
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

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float streak = sin(v_world.z * 1.25 - TIME * 4.0 + sin(v_world.x * 1.6 + TIME) * 1.4);
	float foam = smoothstep(0.93, 1.0, streak) * 0.45;
	float edge = smoothstep(3.5, 4.95, abs(v_world.x)) * 0.7;
	vec2 cell = floor(v_world.xz * 3.0) + floor(TIME * 2.0);
	float sparkle = step(0.988, fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453)) * 0.55;
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, clamp(0.5 + v_wave * 4.0 + fres * 0.4, 0.0, 1.0));
	ALBEDO = mix(base, foam_color.rgb, clamp(foam + edge, 0.0, 1.0)) + vec3(sparkle);
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	ALPHA = mix(alpha, 1.0, fres);
}
