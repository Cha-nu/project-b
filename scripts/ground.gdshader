shader_type spatial;
render_mode specular_disabled;

// 바이옴 지면: 월드 좌표 노이즈로 네 가지 흙색을 섞고 잔 알갱이를 얹는다
uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform float seed = 0.0;
uniform float world = 180.0;

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 1.37) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float n = vnoise(p * 0.09) * 0.7 + vnoise(p * 0.23) * 0.3;
	vec3 col = c1.rgb;
	col = mix(col, c0.rgb, smoothstep(0.18, 0.26, 0.25 - abs(n - 0.12)) );
	col = mix(col, c2.rgb, smoothstep(0.52, 0.6, n));
	col = mix(col, c3.rgb, smoothstep(0.7, 0.78, n));
	float g = hash(floor(p * 6.0));
	col *= 0.93 + g * 0.1;
	float g2 = vnoise(p * 1.7);
	col *= 0.95 + g2 * 0.08;
	// 맵 밖은 어둡게
	float outside = step(p.x, 0.0) + step(world, p.x) + step(p.y, 0.0) + step(world, p.y);
	col *= outside > 0.0 ? 0.45 : 1.0;
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
