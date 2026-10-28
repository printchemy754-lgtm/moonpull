shader_type spatial;
// Patterned ball skins, drawn procedurally from the local surface direction
// (so the pattern rolls with the ball). pattern:
// 1 beach  2 soccer  3 basketball  4 watermelon  5 disco  6 earth  7 eyeball
// 8 lava   9 gold    10 galaxy     11 candy      12 tennis 13 pool-8

uniform int pattern = 1;
uniform vec4 col_a : source_color = vec4(1.0);
uniform vec4 col_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 col_c : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 20 stripes  21 checker  22 dots  23 swirl  24 halves  25 zigzag band
// 26 sparkle gradient  27 rings  28 stars  29 flame  30 pumpkin  31 ornament

varying vec3 p;

void vertex() {
	p = normalize(VERTEX);
}

float hash(vec3 q) {
	return fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float noise(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 q) {
	return noise(q) * 0.55 + noise(q * 2.1) * 0.3 + noise(q * 4.3) * 0.15;
}

void fragment() {
	vec3 c = col_a.rgb;
	float metal = 0.0;
	float rough = 0.45;
	vec3 emit = vec3(0.0);
	float lon = atan(p.z, p.x);
	if (pattern == 1) {            // beach ball: 6 coloured segments + white caps
		int seg = int(floor((lon + PI) / (PI / 3.0)));
		vec3 cols[6] = vec3[6](vec3(0.95, 0.2, 0.2), vec3(1.0, 0.85, 0.15), vec3(0.15, 0.5, 0.95), vec3(1.0), vec3(0.2, 0.8, 0.35), vec3(1.0, 0.55, 0.1));
		c = cols[clamp(seg, 0, 5)];
		if (abs(p.y) > 0.88) c = vec3(1.0);
		rough = 0.3;
	} else if (pattern == 2) {     // soccer: black patches around 12 directions
		float g = 0.8507; float h = 0.5257;
		vec3 d[12] = vec3[12](vec3(0, h, g), vec3(0, h, -g), vec3(0, -h, g), vec3(0, -h, -g), vec3(h, g, 0), vec3(h, -g, 0), vec3(-h, g, 0), vec3(-h, -g, 0), vec3(g, 0, h), vec3(-g, 0, h), vec3(g, 0, -h), vec3(-g, 0, -h));
		float best = 0.0;
		for (int i = 0; i < 12; i++) best = max(best, dot(p, d[i]));
		c = best > 0.93 ? vec3(0.06) : vec3(0.97);
		if (abs(best - 0.93) < 0.01) c = vec3(0.3);
	} else if (pattern == 3) {     // basketball
		c = vec3(0.93, 0.45, 0.12);
		float l = min(min(abs(p.x), abs(p.y)), abs(abs(p.z) - 0.55 - p.y * p.y * 0.35));
		if (l < 0.035) c = vec3(0.08);
		rough = 0.8;
	} else if (pattern == 4) {     // watermelon
		float s = sin(lon * 9.0 + fbm(p * 4.0) * 3.0);
		c = s > 0.2 ? vec3(0.1, 0.38, 0.12) : vec3(0.35, 0.72, 0.25);
		rough = 0.35;
	} else if (pattern == 5) {     // disco: mirror tiles
		vec2 cell = floor(vec2((lon + PI) * 7.0, acos(clamp(p.y, -1.0, 1.0)) * 7.0));
		float r = hash(vec3(cell, 1.0));
		c = vec3(0.7 + 0.3 * r) * vec3(0.9, 0.92, 1.0);
		metal = 0.55;
		rough = 0.12;
		emit = vec3(0.6, 0.6, 1.0) * step(0.985, fract(r * 13.0 + TIME * 0.7)) * 3.0;
		vec2 f = fract(vec2((lon + PI) * 7.0, acos(clamp(p.y, -1.0, 1.0)) * 7.0));
		if (min(min(f.x, f.y), min(1.0 - f.x, 1.0 - f.y)) < 0.06) c = vec3(0.15);
	} else if (pattern == 6) {     // earth
		float n = fbm(p * 2.2 + 3.0);
		c = n > 0.52 ? mix(vec3(0.25, 0.65, 0.2), vec3(0.75, 0.65, 0.35), smoothstep(0.62, 0.75, n)) : vec3(0.1, 0.35, 0.85);
		if (abs(p.y) > 0.85) c = vec3(0.95);
		rough = 0.6;
	} else if (pattern == 7) {     // eyeball (looks forward)
		c = vec3(0.97);
		if (p.z > 0.72) c = col_a.rgb;
		if (p.z > 0.9) c = vec3(0.03);
		if (p.z > 0.97 && p.x > 0.0 && p.y > 0.0) c = vec3(1.0);
		if (p.z < 0.72 && fbm(p * 9.0) > 0.66 && p.z > 0.2) c = vec3(0.9, 0.25, 0.25);
		rough = 0.15;
	} else if (pattern == 8) {     // lava rock
		float n = fbm(p * 3.5);
		c = vec3(0.12, 0.08, 0.08);
		float crack = 1.0 - smoothstep(0.0, 0.05, abs(n - 0.5));
		emit = vec3(1.0, 0.35, 0.05) * crack * (2.5 + sin(TIME * 3.0) * 0.6);
		c = mix(c, vec3(1.0, 0.45, 0.1), crack);
		rough = 0.9;
	} else if (pattern == 9) {     // gold
		c = vec3(1.0, 0.76, 0.22);
		metal = 0.6;
		rough = 0.22;
		emit = vec3(0.25, 0.16, 0.02);
		if (abs(p.y) < 0.03) c = vec3(0.6, 0.4, 0.1);
	} else if (pattern == 10) {    // galaxy
		float n = fbm(p * 2.5);
		c = mix(vec3(0.05, 0.02, 0.15), vec3(0.45, 0.1, 0.6), n);
		float st = step(0.985, hash(floor(p * 40.0)));
		emit = vec3(1.0) * st * 2.0 + vec3(0.3, 0.1, 0.5) * n * 0.6;
		rough = 0.3;
	} else if (pattern == 11) {    // candy swirl
		float s = sin(lon * 4.0 + p.y * 9.0);
		c = s > 0.0 ? vec3(1.0, 0.35, 0.6) : vec3(1.0);
		rough = 0.15;
	} else if (pattern == 12) {    // tennis
		c = vec3(0.82, 0.95, 0.2);
		float seam = abs(p.y - 0.6 * sin(lon * 2.0) * sqrt(max(0.0, 1.0 - p.y * p.y)));
		if (seam < 0.04) c = vec3(1.0);
		rough = 0.95;
	} else if (pattern == 13) {    // pool 8
		c = vec3(0.04);
		if (p.z > 0.75) c = vec3(1.0);
		if (p.z > 0.75 && length(p.xy - vec2(0.0, 0.0)) < 0.25) c = vec3(0.04);
		rough = 0.1;
	}
	if (pattern >= 20) {
		vec3 A = col_a.rgb; vec3 B = col_b.rgb; vec3 C = col_c.rgb;
		float lat = asin(clamp(p.y, -1.0, 1.0));
		rough = 0.35;
		if (pattern == 20) {
			c = mod(floor((lon + PI) / (PI / 4.0)), 2.0) < 1.0 ? A : B;
		} else if (pattern == 21) {
			float k = mod(floor((lon + PI) * 6.0 / PI) + floor((lat + PI) * 6.0 / PI), 2.0);
			c = k < 1.0 ? A : B;
		} else if (pattern == 22) {
			vec3 q = p * 4.0;
			vec3 f = fract(q) - 0.5;
			c = length(f) < 0.28 ? B : A;
		} else if (pattern == 23) {
			float sw = sin(lon * 3.0 + lat * 6.0);
			c = sw > 0.33 ? A : (sw > -0.33 ? B : C);
		} else if (pattern == 24) {
			c = p.y > 0.0 ? A : B;
			if (abs(p.y) < 0.08) c = C;
		} else if (pattern == 25) {
			c = A;
			float z = abs(p.y - 0.18 * sin(lon * 8.0));
			if (z < 0.16) c = B;
			if (z < 0.05) c = C;
		} else if (pattern == 26) {
			c = mix(A, B, p.y * 0.5 + 0.5);
			emit = C * step(0.975, hash(floor(p * 30.0))) * 2.0;
			rough = 0.15;
			metal = 0.3;
		} else if (pattern == 27) {
			c = mod(floor((lat + PI) * 8.0 / PI), 3.0) < 1.0 ? A : (mod(floor((lat + PI) * 8.0 / PI), 3.0) < 2.0 ? B : C);
		} else if (pattern == 28) {
			c = A;
			vec3 q = p * 3.0;
			vec3 f = fract(q) - 0.5;
			float a2 = atan(f.y, f.x);
			float r = length(f.xy) / (0.22 + 0.1 * cos(a2 * 5.0));
			if (r < 1.0 && abs(f.z) < 0.4) c = B;
		} else if (pattern == 29) {
			float n = fbm(p * 3.0 + vec3(0.0, -TIME * 0.8, 0.0));
			c = mix(vec3(1.0, 0.85, 0.2), vec3(0.9, 0.15, 0.05), smoothstep(0.3, 0.7, n + p.y * 0.3));
			emit = c * 0.9;
		} else if (pattern == 30) {
			float rib = abs(sin(lon * 4.0));
			c = mix(vec3(0.85, 0.35, 0.05), vec3(1.0, 0.55, 0.12), rib);
			if (p.y > 0.92) c = vec3(0.25, 0.5, 0.15);
		} else if (pattern == 31) {
			c = A;
			if (abs(p.y) < 0.12) c = vec3(1.0, 0.8, 0.25);
			if (abs(abs(p.y) - 0.3) < 0.03) c = vec3(1.0);
			metal = 0.4;
			rough = 0.15;
		}
	}
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit;
	RIM = 0.3;
}
