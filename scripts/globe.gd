extends Control
## 가상 세계 지구본. 드래그로 돌리고 작전 지점(핀)을 눌러 선택한다.
## 대륙은 고정 시드의 3D 노이즈로 한 번 구워서(정거원통 텍스처) 재사용한다.
## 위도에 따라 바이옴이 정해진다: 적도 = 사막(0), 중위도 = 산림(1), 고위도 = 설원(2)

signal picked(idx: int)

const UI := preload("res://scripts/ui.gd")
const ML := preload("res://scripts/meshlib.gd")
const TW := 768
const TH := 384
const WORLD_SEED := 4242
const DIFF_COL := [Color("#6fd352"), Color("#ffb531"), Color("#ff4a3d")]
const DIFF_N := ["정찰", "교전", "격전"]
const NAMES := [
	["사하르 사구", "카림 협곡", "알자파 시가지", "메사 정유단지", "붉은 고원", "타르 분지", "자라크 오아시스", "하심 염전"],
	["노르발 삼림", "베렌 계곡", "솔트우드 마을", "그린홀 저지대", "이스트마크 숲", "오크린 강변", "라벤 습지", "펠루스 산록"],
	["볼코프 기지", "화이트팽 설원", "북극성 관측소", "프로스트 해협", "아이스게이트", "스노우 크레스트", "베링 빙붕", "카라 동토"],
]

static var _tex: ImageTexture
static var _cloud: ImageTexture
static var _land: PackedByteArray

var vp: SubViewport
var cam: Camera3D
var pivot: Node3D
var clouds: Node3D
var ov: Control
var pins: Array = []
var missions: Array = []
var sel := 0
var yaw := 0.4
var pitch := -0.25
var t_yaw := 0.0
var t_pitch := 0.0
var anim := false
var drag := false
var moved := 0.0
var vel := Vector2.ZERO
var idle := 0.0
var t := 0.0


## ---------- 텍스처 굽기 ----------
static func dir_of(lat: float, lon: float) -> Vector3:
	return Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat))


static func bake() -> void:
	if _tex != null:
		return
	var nz = FastNoiseLite.new()
	nz.seed = WORLD_SEED
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = 5
	nz.frequency = 1.25
	var dn = FastNoiseLite.new()
	dn.seed = WORLD_SEED + 7
	dn.frequency = 3.2
	var img = Image.create(TW, TH, false, Image.FORMAT_RGBA8)
	_land = PackedByteArray()
	_land.resize(TW * TH)
	var deep = Color("#0a2c52")
	var shallow = Color("#1d86c0")
	for j in TH:
		var phi = (0.5 - (j + 0.5) / TH) * PI
		for i in TW:
			var lon = ((i + 0.5) / TW - 0.5) * TAU
			var p = dir_of(phi, lon)
			var h = nz.get_noise_3dv(p) + 0.04
			var jit = dn.get_noise_3dv(p)
			var L = rad_to_deg(absf(phi)) + jit * 9.0
			var c: Color
			var code = 255
			if h <= 0.0:
				c = shallow.lerp(deep, clampf(-h / 0.28, 0, 1))
				if h > -0.025:
					c = c.lerp(Color("#5cc6e0"), 0.45)
				if L > 74:
					c = Color("#dfe9f1").lerp(c, clampf((78 - L) / 4.0, 0, 1))
				img.set_pixel(i, j, Color(c, 0.0))
			else:
				var e = clampf(h / 0.42, 0, 1)
				if L > 56:
					code = 2
					c = Color("#cfdbe6").lerp(Color("#f4f8fb"), e)
				elif L > 25:
					code = 1
					c = Color("#5c9a42").lerp(Color("#2f5f2b"), clampf(e * 1.6 + jit * 0.3, 0, 1))
					if e > 0.55:
						c = Color("#6f6a5a").lerp(Color("#eef2f4"), clampf((e - 0.7) * 4.0, 0, 1))
				else:
					code = 0
					c = Color("#e0bd7e").lerp(Color("#b47f4a"), clampf(e * 1.4 + jit * 0.4, 0, 1))
					if e > 0.6:
						c = Color("#8a5f3c")
				if h < 0.02:
					c = c.lerp(Color("#e8d6a4"), 0.5)
				img.set_pixel(i, j, Color(c, 1.0))
			_land[j * TW + i] = code
	_tex = ImageTexture.create_from_image(img)
	## 구름
	var cn = FastNoiseLite.new()
	cn.seed = WORLD_SEED + 99
	cn.fractal_octaves = 4
	cn.frequency = 2.4
	var cimg = Image.create(256, 128, false, Image.FORMAT_LA8)
	for j in 128:
		var phi = (0.5 - (j + 0.5) / 128.0) * PI
		for i in 256:
			var p = dir_of(phi, ((i + 0.5) / 256.0 - 0.5) * TAU)
			var v = smoothstep(0.08, 0.42, cn.get_noise_3dv(p * 1.3))
			cimg.set_pixel(i, j, Color(1, 1, 1, v * 0.85))
	_cloud = ImageTexture.create_from_image(cimg)


## 육지 위 임의 지점에 작전을 만든다 (기존 지점과 너무 붙지 않게)
static func gen_mission(existing: Array) -> Dictionary:
	bake()
	for tries in 4000:
		var i = randi() % TW
		var j = int(TH * 0.12) + randi() % int(TH * 0.76)
		var code = _land[j * TW + i]
		if code == 255:
			continue
		var lat = (0.5 - (j + 0.5) / TH) * PI
		var lon = ((i + 0.5) / TW - 0.5) * TAU
		var d = dir_of(lat, lon)
		var ok = true
		for m in existing:
			if d.angle_to(dir_of(m.lat, m.lon)) < 0.42:
				ok = false
				break
		if not ok:
			continue
		var r = randf()
		var diff = 0 if r < 0.4 else 1 if r < 0.8 else 2
		var names: Array = NAMES[code]
		return {lat = lat, lon = lon, biome = code, diff = diff, seed = (randi() % 20000) * 3 + code, name = names[randi() % names.size()]}
	return {}


## ---------- 장면 ----------
func _ready() -> void:
	bake()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#040812")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3a5272")
	env.ambient_light_energy = 0.55
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.05, 4.1)
	cam.fov = 36.0
	vp.add_child(cam)
	var sun = DirectionalLight3D.new()
	sun.light_energy = 1.35
	sun.light_color = Color("#fff4e0")
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(-2.2, 1.4, 2.4), Vector3.ZERO)
	## 별
	var stars = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 40.0
	sm.height = 80.0
	stars.mesh = sm
	stars.material_override = _shader_mat(STAR_SH)
	vp.add_child(stars)
	pivot = Node3D.new()
	vp.add_child(pivot)
	var earth = MeshInstance3D.new()
	var em = SphereMesh.new()
	em.radial_segments = 96
	em.rings = 48
	earth.mesh = em
	em.radius = 1.0
	em.height = 2.0
	var emat = _shader_mat(EARTH_SH)
	emat.set_shader_parameter("tex", _tex)
	earth.material_override = emat
	pivot.add_child(earth)
	clouds = MeshInstance3D.new()
	var cm = SphereMesh.new()
	cm.radius = 1.018
	cm.height = 2.036
	cm.radial_segments = 64
	cm.rings = 32
	clouds.mesh = cm
	var cmat = _shader_mat(CLOUD_SH)
	cmat.set_shader_parameter("tex", _cloud)
	clouds.material_override = cmat
	pivot.add_child(clouds)
	var atmo = MeshInstance3D.new()
	var am = SphereMesh.new()
	am.radius = 1.1
	am.height = 2.2
	atmo.mesh = am
	atmo.material_override = _shader_mat(ATMO_SH)
	vp.add_child(atmo)
	## 2D 표시층 (핀 이름표)
	ov = Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.draw.connect(_draw_ov)
	add_child(ov)


func _shader_mat(code: String) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	return m


func set_missions(ms: Array, s: int) -> void:
	missions = ms
	for p in pins:
		p.queue_free()
	pins.clear()
	for m in ms:
		var d = dir_of(m.lat, m.lon)
		var n = Node3D.new()
		var x = d.cross(Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT).normalized()
		var z = x.cross(d)
		n.transform = Transform3D(Basis(x, d, z), d * 0.995)
		var c: Color = DIFF_COL[m.diff]
		ML.cyl(n, 0.007, 0.007, 0.1, "#e8edf2", Vector3(0, 0.05, 0), Vector3.ZERO, 6)
		ML.sph(n, 0.028, c, Vector3(0, 0.11, 0), Vector3.ONE, ML.mat(c, 2.5, 1.0, true), 10)
		var ring = MeshInstance3D.new()
		var rm = TorusMesh.new()
		rm.inner_radius = 0.026
		rm.outer_radius = 0.032
		rm.rings = 24
		rm.ring_segments = 4
		ring.mesh = rm
		ring.material_override = ML.add_mat(c, 0.8)
		ring.name = "Ring"
		ring.position.y = 0.012
		n.add_child(ring)
		pivot.add_child(n)
		pins.append(n)
	select(clampi(s, 0, ms.size() - 1), false)


func select(i: int, emit := true) -> void:
	if missions.is_empty():
		return
	sel = i
	var m: Dictionary = missions[i]
	t_yaw = yaw + wrapf(-m.lon - yaw, -PI, PI)
	t_pitch = clampf(m.lat * 0.9, -1.1, 1.1)
	anim = true
	if emit:
		Synth.beep(880, 0.06, "sine", 0.05)
		picked.emit(i)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			drag = true
			moved = 0.0
			vel = Vector2.ZERO
			anim = false
		else:
			drag = false
			if moved < 16:
				_tap(ev.position)
		accept_event()
	elif ev is InputEventMouseMotion and drag:
		var d: Vector2 = ev.relative
		moved += d.length()
		yaw += d.x * 0.0065
		pitch = clampf(pitch + d.y * 0.0065, -1.2, 1.2)
		vel = d
		idle = 0.0
		accept_event()


func _tap(pos: Vector2) -> void:
	var best = -1
	var bd = 80.0
	for i in pins.size():
		var info = _pin_screen(i)
		if not info[1]:
			continue
		var d = (info[0] as Vector2).distance_to(pos)
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		select(best)


## [화면 좌표, 앞면 여부]
func _pin_screen(i: int) -> Array:
	var n: Node3D = pins[i]
	var wp = n.global_transform * Vector3(0, 0.12, 0)
	var front = (pivot.global_basis * dir_of(missions[i].lat, missions[i].lon)).z > 0.12
	return [cam.unproject_position(wp), front]


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	t += dt
	idle += dt
	if not drag:
		if anim:
			var k = minf(1.0, dt * 5.0)
			yaw = lerpf(yaw, t_yaw, k)
			pitch = lerpf(pitch, t_pitch, k)
			if absf(yaw - t_yaw) < 0.002 and absf(pitch - t_pitch) < 0.002:
				anim = false
		else:
			vel *= pow(0.04, dt)
			yaw += vel.x * 0.0065
			pitch = clampf(pitch + vel.y * 0.0065, -1.2, 1.2)
			if idle > 4.0:
				yaw += dt * 0.05
	pivot.basis = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)
	clouds.rotation.y = t * 0.012
	for i in pins.size():
		## 퍼져 나가며 사라지는 파동 고리
		var r: MeshInstance3D = pins[i].get_node("Ring")
		var k = fmod(t * 0.7 + i * 0.37, 1.0)
		var s = (1.0 + 1.6 * k) * (1.4 if i == sel else 1.0)
		r.scale = Vector3(s, 0.3, s)
		var mt: StandardMaterial3D = r.material_override
		mt.albedo_color.a = (1.0 - k) * 0.85
	ov.queue_redraw()


func _draw_ov() -> void:
	var f = UI.font(true)
	## 위·아래 어둡게 (UI와 자연스럽게 이어지도록)
	var w = size.x
	var h = size.y
	ov.draw_polygon(PackedVector2Array([Vector2(0, h - 260), Vector2(w, h - 260), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(0.016, 0.03, 0.06, 0), Color(0.016, 0.03, 0.06, 0), Color(0.016, 0.03, 0.06, 0.95), Color(0.016, 0.03, 0.06, 0.95)]))
	ov.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 140), Vector2(0, 140)]),
		PackedColorArray([Color(0.016, 0.03, 0.06, 0.85), Color(0.016, 0.03, 0.06, 0.85), Color(0.016, 0.03, 0.06, 0), Color(0.016, 0.03, 0.06, 0)]))
	var order: Array = range(pins.size())
	order.erase(sel)
	order.append(sel)
	for i in order:
		var info = _pin_screen(i)
		if not info[1]:
			continue
		var p: Vector2 = info[0]
		var m: Dictionary = missions[i]
		var c: Color = DIFF_COL[m.diff]
		var on = i == sel
		var fs = 22 if on else 17
		var tw = f.get_string_size(m.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw = tw + (34 if on else 26)
		var bh = 40.0 if on else 30.0
		var r = Rect2(p + Vector2(-bw / 2, -bh - 20), Vector2(bw, bh))
		var sb = UI.pill(Color(0.03, 0.06, 0.1, 0.9) if not on else Color(0.07, 0.1, 0.16, 0.95), c if on else Color(1, 1, 1, 0.15), 10, 4)
		ov.draw_style_box(sb, r)
		ov.draw_circle(r.position + Vector2(14 if on else 11, bh / 2), 5 if on else 4, c)
		ov.draw_string(f, r.position + Vector2(24 if on else 19, bh / 2 + fs * 0.36), m.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT if on else Color(0.85, 0.88, 0.92))
		ov.draw_line(p + Vector2(0, -20), p, Color(c, 0.8), 2)
		if on:
			## 조준 괄호
			var k = 34 + sin(t * 4) * 4
			for sx in [-1, 1]:
				for sy in [-1, 1]:
					var cp = p + Vector2(sx * k, sy * k + 12)
					ov.draw_line(cp, cp - Vector2(sx * 12, 0), UI.GOLD, 3)
					ov.draw_line(cp, cp - Vector2(0, sy * 12), UI.GOLD, 3)


const EARTH_SH := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear, repeat_enable;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 p = normalize(lp);
	float u = atan(p.x, p.z) / (2.0 * PI) + 0.5;
	float v = 0.5 - asin(clamp(p.y, -1.0, 1.0)) / PI;
	vec4 c = texture(tex, vec2(u, v));
	ALBEDO = c.rgb;
	ROUGHNESS = mix(0.32, 0.95, c.a);
	SPECULAR = mix(0.75, 0.15, c.a);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.25, 0.55, 1.0) * fr * 0.5;
}
"""

const CLOUD_SH := """
shader_type spatial;
render_mode depth_draw_never;
uniform sampler2D tex : filter_linear, repeat_enable;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 p = normalize(lp);
	float u = atan(p.x, p.z) / (2.0 * PI) + 0.5;
	float v = 0.5 - asin(clamp(p.y, -1.0, 1.0)) / PI;
	ALBEDO = vec3(1.0);
	ALPHA = texture(tex, vec2(u, v)).a;
	ROUGHNESS = 1.0;
}
"""

const ATMO_SH := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = vec3(0.3, 0.62, 1.0) * pow(f, 2.6) * 1.4;
}
"""

const STAR_SH := """
shader_type spatial;
render_mode unshaded, cull_front;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void fragment() {
	vec3 d = normalize(lp);
	vec3 g = d * 160.0;
	vec3 c = floor(g);
	vec3 f = fract(g) - 0.5;
	float r = h(c);
	float s = step(0.986, r) * smoothstep(0.32, 0.0, length(f));
	vec3 bg = mix(vec3(0.012, 0.02, 0.05), vec3(0.03, 0.05, 0.12), d.y * 0.5 + 0.5);
	ALBEDO = bg + vec3(s) * (0.5 + 0.5 * h(c + 1.0));
}
"""
