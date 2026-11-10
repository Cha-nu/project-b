extends RefCounted
## 병사·전차·드론·포탑·헬기 등 움직이는 모델. 모두 +X 방향을 바라보게 만든다.
## 게임 각도 a(평면 x→, y↓)를 쓰려면 rotation.y = -a 로 돌린다.

const ML := preload("res://scripts/meshlib.gd")

const LOOK := {
	pl = {body = "#6b6a4c", leg = "#5a5a40", vest = "#4a4b35", pouch = "#5e5f44", helm = "#7a7457", face = "#1a1b1c", acc = "#f2c21b", glove = "#222320", gun = 21, pack = "#4f513b", sf = true, k = 1.0},
	ru = {body = "#4a4038", leg = "#3a332c", vest = "#2e2924", helm = "#7d2620", face = "#1a1515", acc = "#c0392b", glove = "#2a2420", gun = 11, k = 0.95},
	sh = {body = "#2c2d31", leg = "#232427", vest = "#1c1d20", helm = "#6a1c18", face = "#4a5058", acc = "#c0392b", glove = "#18191b", gun = 0, shield = true, k = 1.15},
	rf = {body = "#6e6248", leg = "#5a503b", vest = "#4a4130", helm = "#5e2a20", face = "#2a2018", acc = "#c0392b", glove = "#2a2420", gun = 23, pack = "#5a4e36", k = 1.02},
}

static var _flash_mat: StandardMaterial3D


static func flash_mat() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_color = Color(1, 1, 1, 0.85)
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _flash_mat


static func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_collect(c, out)


## 피격 플래시: 모든 부위에 흰 오버레이
static func set_flash(root: Node3D, on: bool) -> void:
	if root.get_meta("flash", false) == on:
		return
	root.set_meta("flash", on)
	for mi in root.get_meta("meshes", []):
		if is_instance_valid(mi):
			mi.material_overlay = flash_mat() if on else null


static func _finish(root: Node3D) -> Node3D:
	var arr: Array = []
	_collect(root, arr)
	root.set_meta("meshes", arr)
	return root


## ---------- 병사 (특수부대 / 적) ----------
static func soldier(type: String, tint := "") -> Node3D:
	var o: Dictionary = LOOK[type]
	var root = Node3D.new()
	var b = Node3D.new()
	b.name = "Body"
	b.scale = Vector3.ONE * o.k
	root.add_child(b)
	var body: String = tint if tint != "" else o.body
	var sf: bool = o.get("sf", false)
	for s in [-1, 1]:
		var hip = Node3D.new()
		hip.name = "HipL" if s < 0 else "HipR"
		hip.position = Vector3(0, 0.85, s * 0.12)
		b.add_child(hip)
		ML.cap(hip, 0.1, 0.82, o.leg, Vector3(0, -0.4, 0))
		ML.box(hip, Vector3(0.28, 0.13, 0.15), "#1b1c1b", Vector3(0.05, -0.79, 0))
		if sf:
			ML.box(hip, Vector3(0.12, 0.15, 0.17), "#2a2b26", Vector3(0.08, -0.45, 0))
	if sf:
		ML.box(b, Vector3(0.12, 0.26, 0.09), "#2e2f28", Vector3(-0.02, 0.7, 0.2))
	ML.box(b, Vector3(0.3, 0.62, 0.46), body, Vector3(0, 1.18, 0))
	ML.box(b, Vector3(0.14, 0.46, 0.42), o.vest, Vector3(0.12, 1.2, 0))
	if sf:
		for z in [-0.13, 0.0, 0.13]:
			ML.box(b, Vector3(0.08, 0.15, 0.11), o.pouch, Vector3(0.22, 1.06, z))
	if o.has("pack"):
		ML.box(b, Vector3(0.2, 0.5, 0.36), o.pack, Vector3(-0.23, 1.22, 0))
	for s in [-1, 1]:
		ML.sph(b, 0.11, body, Vector3(0, 1.44, s * 0.25), Vector3.ONE, null, 8)
	ML.box(b, Vector3(0.05, 0.08, 0.1), o.acc, Vector3(0, 1.45, -0.33))
	ML.sph(b, 0.13, "#8a6e58" if not sf else "#3a332c", Vector3(0.02, 1.62, 0), Vector3.ONE, null, 8)
	ML.sph(b, 0.165, o.helm, Vector3(0, 1.7, 0), Vector3(1, 0.78, 1), null, 10).scale = Vector3(1, 0.78, 1)
	ML.box(b, Vector3(0.07, 0.08, 0.24), o.face, Vector3(0.13, 1.62, 0), Vector3.ZERO, ML.mat(o.face, 0.0, 1.0, false, 0.25))
	if sf:
		ML.box(b, Vector3(0.09, 0.11, 0.08), "#1c1d1e", Vector3(0.15, 1.79, 0))
		for s in [-1, 1]:
			ML.cyl(b, 0.06, 0.06, 0.05, "#2a2b26", Vector3(0, 1.64, s * 0.16), Vector3(PI / 2, 0, 0), 8)
		ML.box(b, Vector3(0.05, 0.05, 0.05), o.acc, Vector3(-0.15, 1.76, 0), Vector3.ZERO, ML.mat(o.acc, 1.5))
	## 총기와 팔
	var g: float = o.gun * 0.038
	if g > 0:
		var gun = Node3D.new()
		gun.name = "Gun"
		gun.position = Vector3(0.15, 1.22, 0.14)
		b.add_child(gun)
		ML.box(gun, Vector3(g, 0.08, 0.06), "#141516", Vector3(g / 2 - 0.05, 0, 0))
		ML.box(gun, Vector3(0.07, 0.17, 0.05), "#2a2c2e", Vector3(0.18, -0.1, 0))
		ML.box(gun, Vector3(0.18, 0.1, 0.05), "#2a2c2e", Vector3(-0.12, -0.02, 0))
		if sf:
			ML.cyl(gun, 0.04, 0.04, 0.2, "#1e1f1f", Vector3(g + 0.05, 0, 0), Vector3(0, 0, PI / 2), 8)
			ML.box(gun, Vector3(0.14, 0.07, 0.05), "#1e1f1f", Vector3(0.22, 0.08, 0))
		ML.beam(b, Vector3(0, 1.42, 0.25), Vector3(0.3, 1.16, 0.15), 0.1, body)
		ML.beam(b, Vector3(0, 1.42, -0.25), Vector3(0.15 + g * 0.55, 1.2, 0.12), 0.1, body)
		ML.sph(b, 0.055, o.glove, Vector3(0.3, 1.16, 0.15), Vector3.ONE, null, 6)
		ML.sph(b, 0.055, o.glove, Vector3(0.15 + g * 0.55, 1.2, 0.12), Vector3.ONE, null, 6)
	else:
		ML.beam(b, Vector3(0, 1.42, 0.25), Vector3(0.38, 1.12, 0.18), 0.1, body)
		ML.beam(b, Vector3(0, 1.42, -0.25), Vector3(0.38, 1.12, -0.18), 0.1, body)
	if o.get("shield", false):
		ML.box(b, Vector3(0.06, 1.15, 0.78), "#555e6a", Vector3(0.48, 0.92, 0))
		ML.box(b, Vector3(0.07, 0.16, 0.4), "#a9c3d6", Vector3(0.49, 1.28, 0), Vector3.ZERO, ML.mat("#a9c3d6", 0.3, 0.8))
	return _finish(root)


## 걷기: 다리를 앞뒤로 흔든다
static func walk(root: Node3D, t: float, amt: float) -> void:
	var b = root.get_node_or_null("Body")
	if b == null:
		return
	var s = sin(t) * 0.55 * amt
	b.get_node("HipL").rotation.z = s
	b.get_node("HipR").rotation.z = -s
	b.position.y = absf(cos(t)) * 0.04 * amt


## ---------- 주력 전차 ----------
static func tank() -> Node3D:
	var root = Node3D.new()
	var hull = Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	for s in [-1, 1]:
		ML.box(hull, Vector3(3.5, 0.62, 0.55), "#1f201d", Vector3(0, 0.33, s * 0.95))
		for i in 6:
			ML.cyl(hull, 0.24, 0.24, 0.58, "#2b2c28", Vector3(-1.4 + i * 0.56, 0.28, s * 0.95), Vector3(PI / 2, 0, 0), 8)
	ML.box(hull, Vector3(3.1, 0.55, 1.6), "#53584a", Vector3(0, 0.82, 0))
	ML.box(hull, Vector3(0.6, 0.3, 1.6), "#646a59", Vector3(1.6, 0.72, 0), Vector3(0, 0, -0.5))
	ML.box(hull, Vector3(0.7, 0.08, 1.2), "#363a30", Vector3(-1.15, 1.12, 0))
	ML.box(hull, Vector3(0.16, 0.06, 1.62), "#a8322a", Vector3(-0.75, 1.11, 0))
	var tur = Node3D.new()
	tur.name = "Turret"
	tur.position = Vector3(0, 1.1, 0)
	root.add_child(tur)
	ML.box(tur, Vector3(1.55, 0.48, 1.25), "#656b5a", Vector3(-0.1, 0.24, 0))
	ML.box(tur, Vector3(0.5, 0.36, 1.0), "#5b6152", Vector3(0.7, 0.2, 0), Vector3(0, 0, 0.3))
	ML.cyl(tur, 0.09, 0.11, 2.3, "#2e3129", Vector3(1.85, 0.28, 0), Vector3(0, 0, PI / 2), 8)
	ML.cyl(tur, 0.15, 0.15, 0.3, "#22241d", Vector3(3.0, 0.28, 0), Vector3(0, 0, PI / 2), 8)
	ML.cyl(tur, 0.2, 0.2, 0.12, "#4a4f41", Vector3(-0.3, 0.52, -0.3), Vector3.ZERO, 8)
	return _finish(root)


## ---------- 쿼드콥터 ----------
static func quad(led: String, body := "#2a2c30") -> Node3D:
	var root = Node3D.new()
	var b = Node3D.new()
	b.name = "Body"
	root.add_child(b)
	ML.beam(b, Vector3(-0.32, 0, -0.32), Vector3(0.32, 0, 0.32), 0.05, "#3a3d42")
	ML.beam(b, Vector3(-0.32, 0, 0.32), Vector3(0.32, 0, -0.32), 0.05, "#3a3d42")
	ML.box(b, Vector3(0.28, 0.1, 0.2), body, Vector3.ZERO)
	ML.box(b, Vector3(0.1, 0.08, 0.08), "#4b5a2e", Vector3(0.14, -0.06, 0))
	for p in [Vector3(0.32, 0.04, 0.32), Vector3(-0.32, 0.04, 0.32), Vector3(0.32, 0.04, -0.32), Vector3(-0.32, 0.04, -0.32)]:
		ML.no_shadow(ML.cyl(b, 0.2, 0.2, 0.01, "#d4d9e0", p, Vector3.ZERO, 12, ML.mat("#d4d9e0", 0.0, 0.35)))
	ML.sph(b, 0.04, led, Vector3(0.15, 0.04, 0), Vector3.ONE, ML.mat(led, 4.0), 6)
	return _finish(root)


## ---------- 센트리 / 박격포 ----------
static func sentry(mortar: bool) -> Node3D:
	var root = Node3D.new()
	for i in 3:
		var a = i / 3.0 * TAU + 0.5
		ML.beam(root, Vector3(0, 0.6, 0), Vector3(cos(a) * 0.7, 0, sin(a) * 0.7), 0.06, "#3a3e36")
	var gun = Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, 0.65, 0)
	root.add_child(gun)
	if mortar:
		ML.cyl(root, 0.5, 0.5, 0.06, "#4a4f45", Vector3(0, 0.03, 0), Vector3.ZERO, 10)
		ML.beam(gun, Vector3(-0.1, -0.5, 0), Vector3(0.35, 0.9, 0), 0.2, "#3a4034")
	else:
		ML.box(gun, Vector3(0.75, 0.32, 0.5), "#5b6152", Vector3(0, 0.12, 0))
		ML.box(gun, Vector3(0.35, 0.25, 0.25), "#3c4134", Vector3(-0.1, 0.1, 0.35))
		ML.cyl(gun, 0.05, 0.05, 1.1, "#1c1e1a", Vector3(0.9, 0.14, 0), Vector3(0, 0, PI / 2), 8)
		ML.sph(gun, 0.05, "#4fa3d9", Vector3(-0.2, 0.3, 0), Vector3.ONE, ML.mat("#4fa3d9", 3.0), 6)
	return _finish(root)


## ---------- 탈출 헬기 (기수가 -Z) ----------
static func heli() -> Node3D:
	var root = Node3D.new()
	ML.sph(root, 1.0, "#56614a", Vector3(0, 0, 0), Vector3(1.3, 1.15, 2.4), null, 12).scale = Vector3(1.3, 1.15, 2.4)
	ML.sph(root, 0.8, "#1d2a33", Vector3(0, 0.25, -1.75), Vector3(1.05, 0.8, 0.9), ML.mat("#1d2a33", 0.0, 1.0, false, 0.15), 10).scale = Vector3(1.05, 0.8, 0.9)
	ML.box(root, Vector3(0.45, 0.45, 4.2), "#47513c", Vector3(0, 0.25, 3.6))
	ML.box(root, Vector3(0.12, 1.3, 0.8), "#3b4432", Vector3(0, 0.85, 5.5))
	ML.box(root, Vector3(1.8, 0.08, 0.5), "#3b4432", Vector3(0, 0.3, 5.3))
	ML.box(root, Vector3(2.66, 0.18, 0.4), "#f2c21b", Vector3(0, -0.1, 0.9))
	ML.box(root, Vector3(1.0, 0.6, 1.6), "#47513c", Vector3(0, 1.1, 0.2))
	for s in [-1, 1]:
		ML.beam(root, Vector3(s * 1.1, -1.35, -1.6), Vector3(s * 1.1, -1.35, 1.6), 0.09, "#2a2e26")
		ML.beam(root, Vector3(s * 0.8, -0.8, -0.8), Vector3(s * 1.1, -1.35, -0.8), 0.07, "#2a2e26")
		ML.beam(root, Vector3(s * 0.8, -0.8, 0.8), Vector3(s * 1.1, -1.35, 0.8), 0.07, "#2a2e26")
	var rot = Node3D.new()
	rot.name = "Rotor"
	rot.position = Vector3(0, 1.55, 0.2)
	root.add_child(rot)
	for i in 4:
		var bl = ML.box(rot, Vector3(4.6, 0.04, 0.28), "#1c1f1a", Vector3(cos(i * PI / 2) * 2.3, 0, sin(i * PI / 2) * 2.3), Vector3(0, -i * PI / 2, 0))
		bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ML.no_shadow(ML.cyl(rot, 4.8, 4.8, 0.02, "#d4dccb", Vector3.ZERO, Vector3.ZERO, 24, ML.mat("#d4dccb", 0.0, 0.12)))
	var tr = Node3D.new()
	tr.name = "TailRotor"
	tr.position = Vector3(0.12, 0.9, 5.6)
	root.add_child(tr)
	ML.box(tr, Vector3(0.04, 1.4, 0.16), "#1c1f1a", Vector3.ZERO)
	ML.sph(root, 0.1, "#ff3a2a", Vector3(0, -0.4, 2.6), Vector3.ONE, ML.mat("#ff3a2a", 4.0), 6).name = "Beacon"
	return _finish(root)


static func crate() -> Node3D:
	var root = Node3D.new()
	ML.box(root, Vector3(1.3, 0.9, 1.1), "#56603a", Vector3(0, 0.45, 0))
	ML.box(root, Vector3(1.32, 0.16, 1.12), "#f2c21b", Vector3(0, 0.6, 0))
	ML.box(root, Vector3(0.12, 0.02, 0.5), "#e8e4d8", Vector3(0, 0.91, 0))
	ML.box(root, Vector3(0.5, 0.02, 0.12), "#e8e4d8", Vector3(0, 0.91, 0))
	return _finish(root)


static func pod() -> Node3D:
	var root = Node3D.new()
	ML.cyl(root, 0.42, 0.42, 1.3, "#5b6152", Vector3(0, 0.65, 0), Vector3.ZERO, 10)
	ML.cyl(root, 0.0, 0.42, 0.45, "#3a3e33", Vector3(0, -0.2, 0), Vector3(PI, 0, 0), 10)
	ML.cyl(root, 0.44, 0.44, 0.18, "#f2c21b", Vector3(0, 0.95, 0), Vector3.ZERO, 10)
	return root


static func beacon_light(col: Color) -> Node3D:
	var root = Node3D.new()
	ML.cyl(root, 0.08, 0.1, 0.4, "#2a2d30", Vector3(0, 0.2, 0), Vector3.ZERO, 8)
	var beam = ML.no_shadow(ML.cyl(root, 0.12, 0.12, 40.0, col, Vector3(0, 20, 0), Vector3.ZERO, 8, ML.add_mat(col, 0.55)))
	beam.name = "Beam"
	var glow = ML.no_shadow(ML.cyl(root, 0.4, 0.4, 40.0, col, Vector3(0, 20, 0), Vector3.ZERO, 10, ML.add_mat(col, 0.12)))
	glow.name = "Glow"
	return root


## 지원 전투기 (+X가 기수). big=true면 폭격기(날개가 길고 엔진 4개)
static func jet(big := false) -> Node3D:
	var root = Node3D.new()
	var hull = "#5f6873"
	var dark = "#3b424b"
	var L = 4.2 if big else 3.0
	ML.box(root, Vector3(L, 0.44, 0.5), hull, Vector3.ZERO)
	ML.box(root, Vector3(0.7, 0.3, 0.36), hull, Vector3(L / 2 + 0.3, -0.03, 0))
	ML.box(root, Vector3(0.6, 0.24, 0.32), "#79c8ff", Vector3(L / 2 - 0.45, 0.3, 0), Vector3.ZERO, ML.mat("#79c8ff", 0.5, 1.0, false, 0.15))
	for s in [-1, 1]:
		if big:
			ML.box(root, Vector3(1.1, 0.08, 3.2), dark, Vector3(0.1, -0.05, s * 1.75), Vector3(0, s * 0.3, 0))
			for k in [1.2, 2.4]:
				ML.cyl(root, 0.13, 0.13, 0.6, dark, Vector3(0.25 - k * 0.15, -0.2, s * k), Vector3(0, 0, PI / 2), 8)
		else:
			ML.box(root, Vector3(1.3, 0.08, 1.5), dark, Vector3(-0.2, -0.05, s * 0.95), Vector3(0, s * 0.45, 0))
		ML.box(root, Vector3(0.6, 0.06, 0.65), dark, Vector3(-L / 2 + 0.2, 0.0, s * 0.45), Vector3(0, s * 0.5, 0))
		ML.box(root, Vector3(0.6, 0.72, 0.06), dark, Vector3(-L / 2 + 0.25, 0.42, s * 0.22), Vector3(s * 0.25, 0, 0))
	var flame = ML.sph(root, 0.22, "#ffb046", Vector3(-L / 2 - 0.15, 0, 0), Vector3(1.6, 1, 1), ML.add_mat("#ffb046", 0.9), 8)
	flame.name = "Flame"
	_no_shadow_all(root)
	return root


static func _no_shadow_all(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no_shadow_all(c)


static func bomb() -> Node3D:
	var root = Node3D.new()
	ML.cap(root, 0.14, 0.6, "#3d4535", Vector3.ZERO)
	ML.box(root, Vector3(0.05, 0.22, 0.22), "#2a2f26", Vector3(0, 0.3, 0))
	_no_shadow_all(root)
	return root
