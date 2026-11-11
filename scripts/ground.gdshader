shader_type spatial;
render_mode specular_disabled;

// 바이옴 지면: 네 가지 흙색을 넓고 부드럽게 섞는다.
// 격자에 정렬된 값 노이즈를 그대로 쓰면 네모난 얼룩(타일을 겹쳐 깐 것처럼)이 보이므로,
// 옥타브마다 좌표를 돌리고 좌표 자체를 노이즈로 휘어서 격자 티를 없앤다.
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
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 옥타브마다 37도쯤 돌려 쌓는 프랙탈 노이즈 (0~1)
float fbm(vec2 p) {
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = r * p * 2.03 + 11.7;
		a *= 0.5;
	}
	return s / 0.9375;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	// 좌표 휘기: 경계가 물 흐르듯 구불거린다
	vec2 q = p + 9.0 * (vec2(fbm(p * 0.035 + 3.1), fbm(p * 0.035 + 17.4)) - 0.5);
	float n = fbm(q * 0.045);
	float m = fbm(q * 0.021 + 40.0);
	// 넓은 구간에 걸쳐 천천히 섞는다 (또렷한 경계 없음)
	vec3 col = mix(c0.rgb, c1.rgb, smoothstep(0.25, 0.6, n));
	col = mix(col, c2.rgb, smoothstep(0.5, 0.85, n) * 0.8);
	col = mix(col, c3.rgb, smoothstep(0.45, 0.8, m) * 0.55);
	// 바람결: 한 방향으로 길게 늘어진 옅은 줄무늬
	vec2 w = vec2(dot(p, vec2(0.92, 0.39)), dot(p, vec2(-0.39, 0.92)));
	float ripple = fbm(vec2(w.x * 0.12, w.y * 1.1) + fbm(p * 0.2) * 1.5);
	col *= 0.95 + ripple * 0.09;
	// 잔 알갱이
	col *= 0.97 + vnoise(p * 7.0 + 5.0) * 0.06;
	// 맵 밖은 어둡게
	float outside = step(p.x, 0.0) + step(world, p.x) + step(p.y, 0.0) + step(world, p.y);
	col *= outside > 0.0 ? 0.38 : 1.0;
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
