shader_type spatial;
render_mode unshaded, cull_front;

// "Inverted hull" ink outline, used as next_pass of toon materials.
uniform vec4 color : source_color = vec4(0.09, 0.07, 0.23, 1.0);
uniform float width = 0.03;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
