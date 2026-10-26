shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec4 deep_color : source_color = vec4(0.05, 0.28, 0.52, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.72, 0.84, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float alpha = 0.86;

varying float v_wave;
varying vec3 v_world;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(w.x * 0.9 + TIME * 2.0) * 0.06
		+ sin(w.z * 0.55 - TIME * 1.7) * 0.09
		+ sin((w.x + w.z) * 1.7 + TIME * 3.1) * 0.025;
	VERTEX.y += wave;
	v_wave = wave;
	v_world = w;
}

void fragment() {
	float streak = sin(v_world.z * 1.25 - TIME * 4.0 + sin(v_world.x * 1.6 + TIME) * 1.4);
	float foam = smoothstep(0.93, 1.0, streak) * 0.55;
	float edge = smoothstep(3.6, 4.9, abs(v_world.x)) * 0.6;
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, clamp(0.55 + v_wave * 4.0, 0.0, 1.0));
	ALBEDO = mix(base, foam_color.rgb, clamp(foam + edge, 0.0, 1.0));
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	ALPHA = alpha;
}
