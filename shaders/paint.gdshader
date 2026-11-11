shader_type canvas_item;
// Turns the clean vector frame into something painted: the line wobbles like a hand,
// ink feathers into the paper (nijimi), pigment pools at edges, and dark strokes
// break up over the tooth of the paper (kasure, dry brush).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 paper = vec3(0.925, 0.878, 0.76);
uniform float strength = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 q = SCREEN_UV * vec2(1280.0, 720.0);
	vec2 unit = 1.0 / vec2(1280.0, 720.0);
	// the hand is never perfectly straight
	vec2 wob = vec2(fbm(q * 0.03), fbm(q * 0.03 + vec2(31.7, 11.3))) - 0.5;
	vec2 uv = SCREEN_UV + wob * unit * 2.4 * strength;
	vec3 c = texture(screen_tex, uv).rgb;
	// feathering and edge pooling
	float j = vnoise(q * 0.8) * 6.2831;
	float rad = 0.9 + 1.1 * vnoise(q * 0.11);
	vec3 acc = vec3(0.0);
	vec3 mn = c;
	for (int i = 0; i < 6; i++) {
		float ang = j + float(i) * 1.0472;
		vec3 s = texture(screen_tex, uv + vec2(cos(ang), sin(ang)) * unit * rad).rgb;
		acc += s;
		mn = min(mn, s);
	}
	vec3 avg = acc / 6.0;
	float edge = clamp(length(c - avg) * 2.0, 0.0, 1.0);
	c = mix(c, mn, 0.16 * strength);
	c *= 1.0 - edge * 0.18 * strength;
	// paper tooth and dry brush
	float lum_p = dot(paper, vec3(0.299, 0.587, 0.114));
	float ink = clamp(1.0 - dot(c, vec3(0.299, 0.587, 0.114)) / lum_p, 0.0, 1.0);
	float fib = fbm(q * vec2(0.5, 0.12) + vec2(0.0, fbm(q * 0.04) * 9.0));
	float grain = fbm(q * 1.6);
	float dry = smoothstep(0.60, 0.86, grain * 0.55 + fib * 0.55);
	c = mix(c, paper * 0.97, dry * ink * 0.50 * strength);
	c *= 0.93 + 0.11 * grain;
	// uneven wash in the mid tones
	float mott = fbm(q * 0.011 + 7.0);
	c = mix(c, c * (0.80 + 0.40 * mott), clamp(ink * (1.0 - ink) * 2.4, 0.0, 1.0) * strength);
	// the sheet has aged unevenly
	c *= 0.95 + 0.09 * fbm(q * 0.004 + 3.0);
	COLOR = vec4(c, 1.0);
}
