shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

// Moonpull "inked cartoon" look: flat toon bands + a soft rim light.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float rim_strength = 0.3;

void fragment() {
	ALBEDO = albedo.rgb;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(0.62, 0.78, rim) * rim_strength;
	EMISSION = emission.rgb * emission_energy + albedo.rgb * rim;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
