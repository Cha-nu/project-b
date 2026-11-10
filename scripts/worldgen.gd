extends RefCounted
## 맵 생성(프로토타입 genMap 이식)과 3D 지형·엄폐물·구조물 조립.
## 논리 좌표는 게임 단위 (x, y). 3D 위치는 (x*K, 높이, y*K).

const Data := preload("res://scripts/data.gd")
const ML := preload("res://scripts/meshlib.gd")

const WORLD := 3000.0
const K := 0.06   ## 미터 / 게임 단위 (수평)
const HS := 0.09  ## 미터 / 게임 단위 (엄폐물 높이)


static func p3(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x * K, h, y * K)


## ---------- 맵 데이터 ----------
static func gen_map(seed_v: int) -> Dictionary:
	var r = RandomNumberGenerator.new()
	r.seed = seed_v
	var biome: Dictionary = Data.BIOMES[seed_v % 3]
	var pt = func() -> Vector2: return Vector2(300 + r.randf() * (WORLD - 600), 300 + r.randf() * (WORLD - 600))
	var start = Vector2.ZERO
	var ext = Vector2.ZERO
	var objs: Array = []
	for tries in 300:
		start = pt.call()
		ext = pt.call()
		objs = []
		for k in 5:
			var q: Vector2 = pt.call()
			for c in 400:
				var bad = q.distance_to(start) < 750 or q.distance_to(ext) < 500
				for o in objs:
					if o.distance_to(q) < 700:
						bad = true
				if not bad:
					break
				q = pt.call()
			objs.append(q)
		var ok = start.distance_to(ext) >= 800
		for i in objs.size():
			if objs[i].distance_to(start) < 750 or objs[i].distance_to(ext) < 500:
				ok = false
			for j in objs.size():
				if i != j and objs[i].distance_to(objs[j]) < 700:
					ok = false
		if ok:
			break
	var roads: Array = [{v = true, p = 500 + r.randf() * 2000, w = 64.0}, {v = false, p = 500 + r.randf() * 2000, w = 64.0}]
	if r.randf() < 0.5:
		roads.append({v = r.randf() < 0.5, p = 400 + r.randf() * 2200, w = 56.0})
	var keep: Array = [start, ext] + objs
	var props: Array = []
	var tot = 0
	for kk in biome.kinds:
		tot += kk[1]
	var nz = FastNoiseLite.new()
	nz.seed = seed_v + 21
	nz.frequency = 1.0 / 260.0
	for i in 2600:
		if props.size() >= 240:
			break
		var x = r.randf() * WORLD
		var y = r.randf() * WORLD
		if nz.get_noise_2d(x, y) * 0.5 + 0.5 < 0.46 + r.randf() * 0.15:
			continue
		var q = r.randf() * tot
		var kind = "rock"
		for kk in biome.kinds:
			q -= kk[1]
			if q < 0:
				kind = kk[0]
				break
		var o = _mk_prop(kind, x, y, r, biome)
		var ext_r: float = maxf(o.hw, o.hh) if o.has("hw") else o.vr
		var m = -8.0 if kind == "car" else ext_r + 8.0
		var on_road = false
		for rd in roads:
			if absf((x if rd.v else y) - rd.p) < rd.w / 2.0 + m:
				on_road = true
		if on_road:
			continue
		var bad = false
		for kp in keep:
			if kp.distance_to(Vector2(x, y)) < o.br + 140:
				bad = true
		for k2 in props:
			if Vector2(k2.x, k2.y).distance_to(Vector2(x, y)) < k2.br + o.br + 18:
				bad = true
		if bad:
			continue
		props.append(o)
	var rg: Array = []
	rg.resize(900)
	for i in 900:
		rg[i] = []
	for k in props:
		rg[int(k.y / 100) * 30 + int(k.x / 100)].append(k)
	var types = ["term", "term", "cap", "nest", "aa"]
	for i in range(types.size() - 1, 0, -1):
		var j = r.randi() % (i + 1)
		var t: String = types[i]
		types[i] = types[j]
		types[j] = t
	var OR = {term = 80.0, cap = 90.0, nest = 30.0, aa = 26.0}
	var OHP = {nest = 1800.0, aa = 1100.0}
	var olist: Array = []
	for i in objs.size():
		var t: String = types[i]
		olist.append({x = objs[i].x, y = objs[i].y, type = t, done = false, prog = 0.0, hp = OHP.get(t, 1.0), maxhp = OHP.get(t, 1.0), spT = 0.0, r = OR[t], known = t == "term" or t == "cap"})
	return {biome = biome, props = props, rg = rg, roads = roads, start = start, ext = ext, objs = olist, seed = seed_v}


## hw/hh가 있으면 상자(AABB) 충돌, 없으면 원(r) 충돌. br은 배치 간격용 반경
static func _mk_prop(kind: String, x: float, y: float, r: RandomNumberGenerator, bm: Dictionary) -> Dictionary:
	var v = [r.randf(), r.randf(), r.randf(), r.randf(), r.randf()]
	var hz = r.randf() < 0.5
	var pick = func(a: Array): return a[r.randi() % a.size()]
	var B = func(a: float, b: float, h: float) -> Dictionary:
		return {kind = kind, x = x, y = y, hw = a if hz else b, hh = b if hz else a, h = h, v = v, br = Vector2(a, b).length()}
	match kind:
		"bld":
			var a = 26 + r.randf() * 30
			var b = 22 + r.randf() * 24
			var o: Dictionary = B.call(a, b, 34 + r.randf() * 40)
			o.hw = a
			o.hh = b
			o.c1 = pick.call(bm.roof)
			o.c2 = pick.call(bm.wall)
			return o
		"car":
			var o: Dictionary = B.call(19, 9, 12)
			o.c1 = pick.call(["#6b2f27", "#3b4a55", "#a8a294", "#38402f", "#4a4038"])
			return o
		"cont":
			var o: Dictionary = B.call(32, 12, 25)
			o.c1 = pick.call(["#8a3b2b", "#2f5878", "#3d6a3c", "#a8772a", "#6e6f70"])
			return o
		"sand":
			var o: Dictionary = B.call(20 + r.randf() * 10, 6, 9)
			o.c1 = "#c9c4b2" if bm.get("snow", false) else "#a8986f"
			return o
		"rock":
			var rad = 12 + r.randf() * 16
			return {kind = kind, x = x, y = y, r = rad, vr = rad, h = rad * 0.7, br = rad, v = v, c1 = bm.rock}
		_:
			var vr = 17 + r.randf() * 13
			return {kind = kind, x = x, y = y, r = 7.0, vr = vr, h = vr * 1.5, br = vr, v = v}


## ---------- 3D 조립 ----------
static func build_world(root: Node3D, m: Dictionary) -> void:
	var bm: Dictionary = m.biome
	_ground(root, m)
	for k in m.props:
		var n = Node3D.new()
		n.position = p3(k.x, k.y)
		root.add_child(n)
		k.node = n
		_prop(n, k, bm)


static func _ground(root: Node3D, m: Dictionary) -> void:
	var bm: Dictionary = m.biome
	var sz = WORLD * K
	var plane = PlaneMesh.new()
	plane.size = Vector2(sz + 80, sz + 80)
	plane.subdivide_width = 0
	var gi = MeshInstance3D.new()
	gi.mesh = plane
	gi.position = Vector3(sz / 2, 0, sz / 2)
	var sh = ShaderMaterial.new()
	sh.shader = preload("res://scripts/ground.gdshader")
	for i in 4:
		sh.set_shader_parameter("c%d" % i, Color(bm.g[i]))
	sh.set_shader_parameter("seed", float(m.seed % 997))
	sh.set_shader_parameter("world", sz)
	gi.material_override = sh
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gi)
	## 도로
	for rd in m.roads:
		var w: float = rd.w * K
		var c = Vector3(rd.p * K, 0.01, sz / 2) if rd.v else Vector3(sz / 2, 0.01, rd.p * K)
		var s_e = Vector3(w + 0.9, 0.02, sz) if rd.v else Vector3(sz, 0.02, w + 0.9)
		var s_r = Vector3(w, 0.03, sz) if rd.v else Vector3(sz, 0.03, w)
		ML.no_shadow(ML.box(root, s_e, bm.roadE, c))
		ML.no_shadow(ML.box(root, s_r, bm.road, c + Vector3(0, 0.005, 0)))
		if bm.lane != "":
			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = ML.box_mesh(Vector3(1.4, 0.04, 0.15) if not rd.v else Vector3(0.15, 0.04, 1.4))
			var n = int(sz / 2.8)
			mm.instance_count = n
			for i in n:
				var t = i * 2.8 + 1.0
				mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rd.p * K, 0.03, t) if rd.v else Vector3(t, 0.03, rd.p * K)))
			var mmi = MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = ML.mat(bm.lane, 0.0, 0.7)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)
	## 바닥 장식: 자갈·풀
	var r = RandomNumberGenerator.new()
	r.seed = m.seed + 5
	for kind in 2:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ML.sph_mesh(0.12, 6, 3) if kind == 0 else ML.cyl_mesh(0.0, 0.07, 0.35, 4)
		mm.instance_count = 1800
		for i in 1800:
			var b = Basis().rotated(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * (0.6 + r.randf() * 1.2))
			mm.set_instance_transform(i, Transform3D(b, Vector3(r.randf() * sz, 0.04 if kind == 0 else 0.15, r.randf() * sz)))
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = ML.mat(bm.rock if kind == 0 else bm.deco)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	## 맵 경계
	for i in 4:
		var horiz = i < 2
		var pos = Vector3(sz / 2, 0.05, 0 if i == 0 else sz) if horiz else Vector3(0 if i == 2 else sz, 0.05, sz / 2)
		ML.no_shadow(ML.box(root, Vector3(sz, 0.06, 0.3) if horiz else Vector3(0.3, 0.06, sz), "#f2c21b", pos, Vector3.ZERO, ML.mat("#f2c21b", 0.6, 0.7, true)))


static func _prop(n: Node3D, k: Dictionary, bm: Dictionary) -> void:
	var v: Array = k.v
	match k.kind:
		"bld":
			var w: float = k.hw * 2 * K
			var d: float = k.hh * 2 * K
			var h: float = k.h * HS
			ML.box(n, Vector3(w, h, d), k.c2, Vector3(0, h / 2, 0))
			ML.box(n, Vector3(w + 0.1, 0.12, d + 0.1), k.c1, Vector3(0, h + 0.06, 0))
			var pc = Color(k.c1).darkened(0.12)
			for s in [-1, 1]:
				ML.box(n, Vector3(w + 0.1, 0.45, 0.15), pc, Vector3(0, h + 0.3, s * (d / 2)))
				ML.box(n, Vector3(0.15, 0.45, d + 0.1), pc, Vector3(s * (w / 2), h + 0.3, 0))
			## 창문 (남·북·동·서)
			var win = ML.mat("#15181b", 0.0, 1.0, false, 0.3)
			var floors = maxi(1, int(h / 2.6))
			var nx = maxi(1, int(w / 1.6))
			var nz = maxi(1, int(d / 1.6))
			for f in floors:
				var wy = 1.2 + f * 2.6
				if wy > h - 0.6:
					break
				for i in nx:
					var wx = -w / 2 + (i + 0.5) * w / nx
					for s in [-1, 1]:
						ML.box(n, Vector3(0.5, 0.9, 0.06), "", Vector3(wx, wy, s * (d / 2 + 0.01)), Vector3.ZERO, win)
				for i in nz:
					var wz = -d / 2 + (i + 0.5) * d / nz
					for s in [-1, 1]:
						ML.box(n, Vector3(0.06, 0.9, 0.5), "", Vector3(s * (w / 2 + 0.01), wy, wz), Vector3.ZERO, win)
			ML.box(n, Vector3(1.0, 1.9, 0.08), "#0e0f10", Vector3(-w * 0.2 + v[0] * w * 0.4, 0.95, d / 2 + 0.02))
			ML.box(n, Vector3(0.7, 0.4, 0.5), Color(k.c1).lightened(0.1), Vector3(-w * 0.3 + v[1] * w * 0.5, h + 0.35, -d * 0.3 + v[2] * d * 0.5))
			if v[3] < 0.5:
				ML.cyl(n, 0.32, 0.32, 0.6, Color(k.c1).darkened(0.1), Vector3(w * 0.15 + v[0] * w * 0.2, h + 0.45, d * 0.1))
		"cont":
			var w: float = k.hw * 2 * K
			var d: float = k.hh * 2 * K
			var h: float = k.h * HS
			ML.box(n, Vector3(w, h, d), k.c1, Vector3(0, h / 2, 0))
			var dark = Color(k.c1).darkened(0.3)
			var long_x: bool = k.hw > k.hh
			var L = w if long_x else d
			var cnt = int(L / 0.45)
			for i in cnt:
				var t = -L / 2 + (i + 0.5) * L / cnt
				if long_x:
					ML.box(n, Vector3(0.06, h * 0.9, d + 0.04), dark, Vector3(t, h / 2, 0))
				else:
					ML.box(n, Vector3(w + 0.04, h * 0.9, 0.06), dark, Vector3(0, h / 2, t))
		"car":
			var long_x: bool = k.hw > k.hh
			var w: float = k.hw * 2 * K
			var d: float = k.hh * 2 * K
			var body: Color = Color(k.c1)
			ML.box(n, Vector3(w, 0.55, d), body, Vector3(0, 0.45, 0))
			var cw = w * (0.5 if long_x else 0.92)
			var cd = d * (0.92 if long_x else 0.5)
			ML.box(n, Vector3(cw, 0.45, cd), "#1d262e", Vector3(0, 0.95, 0))
			ML.box(n, Vector3(cw * 0.9, 0.06, cd * 0.9), body.lightened(0.08), Vector3(0, 1.2, 0))
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var wp = Vector3(sx * w * 0.32, 0.25, sz * d / 2) if long_x else Vector3(sx * w / 2, 0.25, sz * d * 0.32)
					ML.cyl(n, 0.25, 0.25, 0.2, "#141414", wp, Vector3(PI / 2, 0, 0) if long_x else Vector3(0, 0, PI / 2), 8)
			if v[0] < 0.45:
				ML.box(n, Vector3(w * 0.8, 0.02, d * 0.8), "#111111", Vector3(0, 1.24, 0), Vector3.ZERO, ML.mat("#000000", 0.0, 0.55))
		"sand":
			var long_x: bool = k.hw > k.hh
			var L: float = (k.hw if long_x else k.hh) * 2 * K
			var cnt = maxi(2, int(L / 0.5))
			for row in 2:
				for i in cnt - row:
					var t = -L / 2 + (i + 0.5 + row * 0.5) * L / cnt
					var pos = Vector3(t, 0.18 + row * 0.3, 0) if long_x else Vector3(0, 0.18 + row * 0.3, t)
					var sc = Vector3(L / cnt * 1.05, 0.34, 0.6) if long_x else Vector3(0.6, 0.34, L / cnt * 1.05)
					var mi = ML.sph(n, 0.5, k.c1, pos, sc, null, 8)
					mi.scale = sc
		"rock":
			var rr: float = k.r * K
			var mi = ML.sph(n, 1.0, k.c1, Vector3(0, k.h * HS * 0.35, 0), Vector3(rr * 1.05, k.h * HS * 0.8, rr * 0.9), null, 7)
			mi.rotation.y = v[0] * TAU
		"tree":
			var vr: float = k.vr * K
			var h: float = k.h * HS * 0.7
			ML.cyl(n, 0.14, 0.2, h, "#4a3626", Vector3(0, h / 2, 0), Vector3.ZERO, 6)
			for i in 5:
				var a: float = i / 5.0 * TAU + v[0] * 6
				ML.sph(n, vr * 0.55, "#36602c" if i % 2 else "#3f6c32", Vector3(cos(a) * vr * 0.45, h + 0.2 + (i % 2) * 0.3, sin(a) * vr * 0.45), Vector3.ONE, null, 8)
			ML.sph(n, vr * 0.6, "#4b7a3a", Vector3(0, h + 0.7, 0), Vector3.ONE, null, 8)
		"pine":
			var vr: float = k.vr * K
			var h: float = k.h * HS
			ML.cyl(n, 0.1, 0.16, h * 0.4, "#4a3626", Vector3(0, h * 0.2, 0), Vector3.ZERO, 6)
			for l in 3:
				var rr = vr * (1.0 - l * 0.27)
				var y0 = h * (0.22 + l * 0.24)
				ML.cyl(n, 0.0, rr, h * 0.42, "#2f5a40" if l % 2 else "#284d37", Vector3(0, y0 + h * 0.21, 0), Vector3.ZERO, 8)
				if bm.get("snow", false):
					ML.cyl(n, 0.0, rr * 0.55, h * 0.2, "#e9eef2", Vector3(0, y0 + h * 0.33, 0), Vector3.ZERO, 8)
		"palm":
			var vr: float = k.vr * K
			var h: float = k.h * HS
			var top = Vector3(0.25, h, 0.1)
			ML.beam(n, Vector3.ZERO, top, 0.28, "#7a6040")
			for i in 8:
				var a: float = i / 8.0 * TAU + v[0] * 6
				var tip = top + Vector3(cos(a) * vr, -0.9, sin(a) * vr)
				var mid = top + Vector3(cos(a) * vr * 0.5, 0.25, sin(a) * vr * 0.5)
				ML.beam(n, top, mid, 0.32, "#66843c" if i % 2 else "#526e2e").scale.x = 2.4
				ML.beam(n, mid, tip, 0.3, "#66843c" if i % 2 else "#526e2e").scale.x = 2.0


## ---------- 임무 구조물 ----------
static func build_struct(o: Dictionary) -> Node3D:
	var n = Node3D.new()
	var live = Node3D.new()
	live.name = "Live"
	n.add_child(live)
	var dead = Node3D.new()
	dead.name = "Dead"
	dead.visible = false
	n.add_child(dead)
	match o.type:
		"cap":
			ML.box(live, Vector3(1.7, 0.4, 1.7), "#73787b", Vector3(0, 0.2, 0))
			var H = 8.5
			var c = [Vector3(-0.6, 0.4, -0.6), Vector3(0.6, 0.4, -0.6), Vector3(0.6, 0.4, 0.6), Vector3(-0.6, 0.4, 0.6)]
			var t = [Vector3(-0.15, H, -0.15), Vector3(0.15, H, -0.15), Vector3(0.15, H, 0.15), Vector3(-0.15, H, 0.15)]
			for i in 4:
				ML.beam(live, c[i], t[i], 0.12, "#2a2d30")
			for s in 6:
				var f0 = s / 6.0
				var f1 = (s + 1) / 6.0
				for i in 4:
					var j = (i + 1) % 4
					ML.beam(live, c[i].lerp(t[i], f0), c[j].lerp(t[j], f1), 0.05, "#8d959c")
			ML.box(live, Vector3(0.5, 0.45, 0.5), "#6d7378", Vector3(0, H + 0.2, 0))
			ML.cyl(live, 0.45, 0.3, 0.15, "#d9dde2", Vector3(0.4, H + 0.1, 0.1), Vector3(0, 0, PI / 2.4), 12)
			var lamp = ML.sph(live, 0.13, "#ff3a2a", Vector3(0, H + 0.6, 0), Vector3.ONE, ML.mat("#ff3a2a", 3.0))
			lamp.name = "Lamp"
			for gp in [Vector3(-2.6, 0, -2), Vector3(2.6, 0, -2), Vector3(-2.4, 0, 2.2), Vector3(2.4, 0, 2.2)]:
				ML.beam(live, Vector3(0, H - 0.6, 0), gp, 0.025, "#1a1c1e")
		"nest":
			ML.box(live, Vector3(4.3, 2.0, 3.1), "#6a6d66", Vector3(0, 1.0, 0))
			ML.box(live, Vector3(4.4, 0.15, 3.2), "#80837b", Vector3(0, 2.05, 0))
			ML.box(live, Vector3(1.9, 0.6, 1.1), "#8c8f87", Vector3(0, 2.4, -0.5))
			ML.box(live, Vector3(2.9, 0.22, 0.05), "#0c0d0e", Vector3(0, 1.1, 1.56))
			ML.box(live, Vector3(0.9, 1.4, 0.05), "#0c0d0e", Vector3(1.4, 0.7, 1.56))
			ML.beam(live, Vector3(1.6, 2.1, -1.1), Vector3(1.6, 4.6, -1.1), 0.06, "#2a2a2a")
			var flag = ML.box(live, Vector3(1.1, 0.6, 0.03), "#b8322a", Vector3(2.15, 4.25, -1.1))
			flag.name = "Flag"
			for i in 7:
				ML.sph(live, 0.5, "#a8996f" if i % 2 else "#9a8c66", Vector3(-2.5 + i * 0.8, 0.22, 2.1), Vector3(0.8, 0.36, 0.5), null, 8).scale = Vector3(0.8, 0.36, 0.5)
		"term":
			ML.box(live, Vector3(1.2, 1.6, 0.85), "#3e444c", Vector3(0, 0.8, 0))
			ML.box(live, Vector3(1.3, 0.1, 0.95), "#4a5058", Vector3(0, 1.65, 0))
			var scr = ML.box(live, Vector3(0.85, 0.6, 0.05), "#f2a33a", Vector3(0, 1.05, 0.44), Vector3.ZERO, ML.mat("#f2a33a", 2.5))
			scr.name = "Screen"
			ML.beam(live, Vector3(0.45, 1.7, -0.3), Vector3(0.55, 3.2, -0.3), 0.04, "#2a2a2a")
			var lamp = ML.sph(live, 0.08, "#ff3a2a", Vector3(0.55, 3.25, -0.3), Vector3.ONE, ML.mat("#ff3a2a", 3.0))
			lamp.name = "Lamp"
		"aa":
			ML.cyl(live, 1.25, 1.35, 0.7, "#62655d", Vector3(0, 0.35, 0), Vector3.ZERO, 8)
			ML.cyl(live, 1.3, 1.3, 0.05, "#7a7d74", Vector3(0, 0.72, 0), Vector3.ZERO, 8)
			var tur = Node3D.new()
			tur.name = "Turret"
			tur.position = Vector3(0, 0.75, 0)
			live.add_child(tur)
			ML.box(tur, Vector3(1.1, 0.7, 0.95), "#5b6050", Vector3(0, 0.35, 0))
			ML.box(tur, Vector3(0.5, 0.3, 0.3), "#3c4134", Vector3(-0.4, 0.75, 0))
			for s in [-0.22, 0.22]:
				ML.beam(tur, Vector3(0.3, 0.6, s), Vector3(1.5, 2.6, s), 0.13, "#2a2c26")
			for i in 8:
				var a = i / 8.0 * TAU
				ML.sph(live, 0.5, "#a8996f", Vector3(cos(a) * 2.1, 0.2, sin(a) * 2.1), Vector3(0.9, 0.36, 0.5), null, 8).scale = Vector3(0.9, 0.36, 0.5)
	## 파괴 후 잔해
	for i in 5:
		var a = i * 1.3
		ML.box(dead, Vector3(0.6 + (i % 3) * 0.3, 0.4 + (i % 2) * 0.3, 0.5 + (i % 2) * 0.4), "#5d605a", Vector3(cos(a) * 1.2, 0.2, sin(a) * 0.9), Vector3(0, a, 0.1 * i))
	n.position = p3(o.x, o.y)
	return n
