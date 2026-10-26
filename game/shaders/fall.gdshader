shader_type spatial;
render_mode unshaded, cull_disabled;

// Waterfall / lavafall: scrolling stripes on a quad.
uniform vec4 color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float glow = 0.2;

void fragment() {
	float s = sin(UV.y * 38.0 + TIME * 10.0 + sin(UV.x * 14.0) * 2.0) * 0.5 + 0.5;
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	ALBEDO = color.rgb * (0.75 + 0.35 * s) * (1.0 + glow * 0.4);
	ALPHA = (0.7 + 0.25 * s) * edge;
}
