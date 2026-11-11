extends RefCounted
## 맵 생성(프로토타입 genMap 이식)과 3D 지형·엄폐물·구조물 조립.
## 논리 좌표는 게임 단위 (x, y). 3D 위치는 (x*K, 높이, y*K).

const Data := preload("res://scripts/data.gd")
const ML := preload("res://scripts/meshlib.gd")
const MK := preload("res://scripts/modelkit.gd")

const WORLD := 3000.0
const K := 0.06   ## 미터 / 게임 단위 (수평)
const HS := 0.09  ## 미터 / 게임 단위 (엄폐물 높이)


static func p3(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x * K, h, y * K)


## ---------- 맵 데이터 ----------
## stage: 보조 목표가 스테이지에 따라 하나씩 늘어난다 (1: 통신탑만 → 6: 전부)
static func gen_map(seed_v: int, stage := 10) -> Dictionary:
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
		for k in (1 if Data.BOSS.has(stage) else 2) + Data.stage_objs(stage).size():
			var q: Vector2 = pt.call()
			for c in 400:
				var bad = q.distance_to(start) < 750 or q.distance_to(ext) < 500
				for o in objs:
					if o.distance_to(q) < 620:
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
				if i != j and objs[i].distance_to(objs[j]) < 620:
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
	## 보스 스테이지는 단말기 대신 보스 지점 하나가 주 임무다
	var types: Array = (["boss"] if Data.BOSS.has(stage) else ["term", "term"]) + Data.stage_objs(stage)
	for i in range(types.size() - 1, 0, -1):
		var j = r.randi() % (i + 1)
		var t: String = types[i]
		types[i] = types[j]
		types[j] = t
	var OR = {boss = 70.0, term = 80.0, cap = 90.0, nest = 46.0, aa = 28.0, jam = 28.0, fac = 68.0}
	var OHP = {nest = 1800.0, aa = 1100.0, jam = 900.0, fac = 2600.0}
	var olist: Array = []
	for i in objs.size():
		var t: String = types[i]
		olist.append({x = objs[i].x, y = objs[i].y, type = t, done = false, prog = 0.0, hp = OHP.get(t, 1.0), maxhp = OHP.get(t, 1.0), spT = 0.0, r = OR[t], known = t == "term" or t == "cap" or t == "boss", hacked = false, code = "", hackN = 0, hackT = 0.0, scoutT = 0.0})
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
	_contact(root, m)


## 접지 그림자: 엄폐물 밑동을 따라 바닥을 어둡게 깐다 (값싼 앰비언트 오클루전, 메시 하나)
static func _contact(root: Node3D, m: Dictionary) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark = Color(0.03, 0.03, 0.07, 0.46)
	var clear = Color(0.03, 0.03, 0.07, 0.0)
	var y = 0.045
	var n = 0
	for k in m.props:
		if k.has("hw"):
			var hw: float = k.hw * K
			var hh: float = k.hh * K
			var mg: float = clampf(k.h * HS * 0.3, 0.45, 1.5)
			var c = p3(k.x, k.y, y)
			var sg = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			for j in 4:
				var a: Vector2 = sg[j]
				var b: Vector2 = sg[(j + 1) % 4]
				var ia = c + Vector3(a.x * hw, 0, a.y * hh)
				var ib = c + Vector3(b.x * hw, 0, b.y * hh)
				var oa = c + Vector3(a.x * (hw + mg), 0, a.y * (hh + mg))
				var ob = c + Vector3(b.x * (hw + mg), 0, b.y * (hh + mg))
				for q in [[ia, dark], [ib, dark], [ob, clear], [ia, dark], [ob, clear], [oa, clear]]:
					st.set_color(q[1])
					st.add_vertex(q[0])
					n += 1
		else:
			## 바위·나무: 가운데가 짙은 원
			var r: float = (k.r * 1.5 if k.kind == "rock" else k.vr * 0.85) * K
			var c = p3(k.x, k.y, y)
			var dk = dark if k.kind == "rock" else Color(dark, 0.3)
			for j in 14:
				var a0 = j / 14.0 * TAU
				var a1 = (j + 1) / 14.0 * TAU
				for q in [[c, dk], [c + Vector3(cos(a0) * r, 0, sin(a0) * r), clear], [c + Vector3(cos(a1) * r, 0, sin(a1) * r), clear]]:
					st.set_color(q[1])
					st.add_vertex(q[0])
					n += 1
	if n == 0:
		return
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ML.vcol_mat(false, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


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
	var snow: bool = bm.get("snow", false)
	match k.kind:
		"bld":
			MK.inst(n, _bld_mesh(k, bm))
		"cont":
			var c1: String = k.c1
			var mi = MK.inst(n, MK.cached("cont_" + c1, func(): return _cont_mesh(c1)))
			if k.hw < k.hh:
				mi.rotation.y = PI / 2
		"car":
			var c1: String = k.c1
			var mi = MK.inst(n, MK.cached("car_" + c1, func(): return _car_mesh(c1)))
			mi.rotation.y = (0.0 if k.hw > k.hh else PI / 2) + (PI if v[1] < 0.5 else 0.0)
		"sand":
			var long_x: bool = k.hw > k.hh
			var L: float = (k.hw if long_x else k.hh) * 2 * K
			var cnt = maxi(2, int(L / 0.5))
			var c1: String = k.c1
			var mi = MK.inst(n, MK.cached("sand_%d_%s" % [cnt, c1], func(): return _sand_mesh(cnt, c1)))
			mi.scale.x = L / (cnt * 0.5)
			if not long_x:
				mi.rotation.y = PI / 2
		"rock":
			var var_i = int(v[1] * 2.99)
			var c1: String = k.c1
			var mi = MK.inst(n, MK.cached("rock_%d_%s_%s" % [var_i, c1, snow], func(): return _rock_mesh(var_i, c1, snow)))
			mi.scale = Vector3.ONE * k.r * K
			mi.rotation.y = v[0] * TAU
		"tree":
			var var_i = int(v[1] * 2.99)
			var mi = MK.inst(n, MK.cached("tree_%d" % var_i, func(): return _tree_mesh(var_i)))
			mi.scale = Vector3.ONE * k.vr * K
			mi.rotation.y = v[0] * TAU
		"pine":
			var var_i = int(v[1] * 1.99)
			var mi = MK.inst(n, MK.cached("pine_%d_%s" % [var_i, snow], func(): return _pine_mesh(var_i, snow)))
			mi.scale = Vector3.ONE * k.vr * K
			mi.rotation.y = v[0] * TAU
		"palm":
			var var_i = int(v[1] * 1.99)
			var mi = MK.inst(n, MK.cached("palm_%d" % var_i, func(): return _palm_mesh(var_i)))
			mi.scale = Vector3.ONE * k.vr * K
			mi.rotation.y = v[0] * TAU


## ---------- 엄폐물 메시 (종류마다 메시 하나) ----------
## 건물: 크기가 제각각이라 건물마다 따로 만든다. 창·문·옥상 설비까지 메시 하나
static func _bld_mesh(k: Dictionary, bm: Dictionary) -> Mesh:
	var b = MK.new()
	var v: Array = k.v
	var w: float = k.hw * 2 * K
	var d: float = k.hh * 2 * K
	var h: float = k.h * HS
	var wall = Color(str(k.c2))
	var roof = Color(str(k.c1))
	var snow: bool = bm.get("snow", false)
	var gable: bool = bm.n == "산림 마을" and v[3] < 0.65
	var r = RandomNumberGenerator.new()
	r.seed = int(k.x * 31 + k.y * 17)
	b.box(Vector3(w, h, d), Vector3(0, h / 2, 0), wall)
	b.box(Vector3(w + 0.16, 0.42, d + 0.16), Vector3(0, 0.21, 0), wall.darkened(0.32), Vector3.ZERO, 0.04)
	## 모서리 기둥
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.22, h, 0.22), Vector3(sx * (w / 2 - 0.06), h / 2, sz * (d / 2 - 0.06)), wall.lightened(0.1))
	var floors = maxi(1, int(h / 2.6))
	for f in range(1, floors):
		b.box(Vector3(w + 0.08, 0.1, d + 0.08), Vector3(0, f * 2.6 - 0.1, 0), wall.lightened(0.16))
	## 창: 틀 + 유리(일부는 불이 켜져 있다) + 창턱
	var frame = wall.lightened(0.26)
	var glass = Color("#1c2c3c")
	var nx = maxi(1, int(w / 1.6))
	var nz = maxi(1, int(d / 1.6))
	for f in floors:
		var wy = 1.25 + f * 2.6
		if wy > h - 0.6:
			break
		for side in 4:
			var cnt = nx if side < 2 else nz
			var span = w if side < 2 else d
			var sg = -1.0 if side % 2 == 0 else 1.0
			for i in cnt:
				var t = -span / 2 + (i + 0.5) * span / cnt
				var lit = r.randf() < 0.16
				var pos = Vector3(t, wy, sg * (d / 2)) if side < 2 else Vector3(sg * (w / 2), wy, t)
				var out = Vector3(0, 0, sg) if side < 2 else Vector3(sg, 0, 0)
				var fs = Vector3(0.66, 1.06, 0.06) if side < 2 else Vector3(0.06, 1.06, 0.66)
				var gs = Vector3(0.5, 0.9, 0.09) if side < 2 else Vector3(0.09, 0.9, 0.5)
				var ss = Vector3(0.76, 0.07, 0.2) if side < 2 else Vector3(0.2, 0.07, 0.76)
				b.box(fs, pos + out * 0.01, frame)
				b.glow = lit
				b.box(gs, pos + out * 0.01, Color("#ffd596") if lit else glass)
				b.glow = false
				b.box(ss, pos + out * 0.07 + Vector3(0, -0.56, 0), frame)
				## 가끔 실외기
				if r.randf() < 0.12:
					b.box(Vector3(0.5, 0.36, 0.3) if side < 2 else Vector3(0.3, 0.36, 0.5), pos + out * 0.17 + Vector3(0, -0.86, 0), "#b9bcb8", Vector3.ZERO, 0.03)
	## 문 + 문틀 + 차양 + 디딤돌
	var dx: float = -w * 0.2 + v[0] * w * 0.4
	b.box(Vector3(1.24, 2.1, 0.08), Vector3(dx, 1.05, d / 2 + 0.01), frame)
	b.box(Vector3(1.0, 1.92, 0.12), Vector3(dx, 0.96, d / 2 + 0.01), "#2a211a" if not snow else "#3a4450")
	b.box(Vector3(0.06, 0.06, 0.16), Vector3(dx + 0.36, 1.0, d / 2 + 0.03), "#c8b060")
	b.box(Vector3(1.5, 0.12, 0.5), Vector3(dx, 0.06, d / 2 + 0.3), wall.darkened(0.4), Vector3.ZERO, 0.02)
	var aw: String = ["#b5483a", "#2f6f8f", "#c9a13a", "#3f7a52"][int(v[4] * 3.99)]
	b.box(Vector3(1.6, 0.07, 0.75), Vector3(dx, 2.28, d / 2 + 0.33), aw, Vector3(0.3, 0, 0), 0.02)
	for sx in [-0.72, 0.72]:
		b.beam(Vector3(dx + sx, 2.18, d / 2 + 0.66), Vector3(dx + sx, 1.9, d / 2 + 0.02), 0.02, 0.02, "#2a2a2a", 4)
	if gable:
		## 맞배지붕: 긴 변을 따라 용마루
		var along_x = w >= d
		var half = (d if along_x else w) / 2 + 0.3
		var len = (w if along_x else d) / 2 + 0.3
		var rh = clampf(half * 0.62, 0.8, 1.9)
		var P = func(a: float, c: float, y: float) -> Vector3: return Vector3(a, y, c) if along_x else Vector3(c, y, a)
		var rc = roof if not snow else Color("#e9eef2")
		for sg in [-1.0, 1.0]:
			var out: Vector3 = P.call(0.0, sg, 1.0)
			b.quad(P.call(-len, sg * half, h - 0.05), P.call(len, sg * half, h - 0.05), P.call(len, 0.0, h + rh), P.call(-len, 0.0, h + rh), rc if sg > 0 else rc.darkened(0.1), out)
			b.quad(P.call(-len, sg * half, h - 0.17), P.call(len, sg * half, h - 0.17), P.call(len, sg * half, h - 0.05), P.call(-len, sg * half, h - 0.05), rc.darkened(0.3), out)
			## 박공 벽
			var gx = sg * ((w if along_x else d) / 2)
			b.tri(P.call(gx, -half + 0.3, h), P.call(gx, half - 0.3, h), P.call(gx, 0.0, h + rh * (1.0 - 0.3 / half)), wall.lightened(0.05), P.call(sg, 0.0, 0.0))
		b.box(Vector3(len * 2 + 0.1, 0.1, 0.22) if along_x else Vector3(0.22, 0.1, len * 2 + 0.1), Vector3(0, h + rh, 0), rc.darkened(0.25), Vector3.ZERO, 0.03)
		## 굴뚝
		var cp: Vector3 = P.call(len * (0.5 - v[1]), half * 0.45, h + rh * 0.55 + 0.4)
		b.box(Vector3(0.5, 1.0, 0.5), cp, "#7a5a4a", Vector3.ZERO, 0.03)
		b.box(Vector3(0.6, 0.1, 0.6), cp + Vector3(0, 0.5, 0), "#3a3432")
	else:
		## 평지붕: 난간 + 옥상 바닥 + 설비
		var rc = roof if not snow else Color("#e4eaee")
		b.box(Vector3(w + 0.14, 0.14, d + 0.14), Vector3(0, h + 0.05, 0), roof)
		b.box(Vector3(w - 0.3, 0.03, d - 0.3), Vector3(0, h + 0.135, 0), rc.darkened(0.25) if not snow else rc)
		var pc = roof.darkened(0.12)
		for sg in [-1.0, 1.0]:
			b.box(Vector3(w + 0.14, 0.48, 0.17), Vector3(0, h + 0.33, sg * (d / 2)), pc, Vector3.ZERO, 0.03)
			b.box(Vector3(0.17, 0.48, d + 0.14), Vector3(sg * (w / 2), h + 0.33, 0), pc, Vector3.ZERO, 0.03)
		## 실외기 + 환풍구
		var ap = Vector3(-w * 0.3 + v[1] * w * 0.5, h + 0.42, -d * 0.3 + v[2] * d * 0.5)
		b.box(Vector3(0.9, 0.55, 0.65), ap, "#aeb2ad", Vector3.ZERO, 0.05)
		b.cyl(0.2, 0.2, 0.04, ap + Vector3(0, 0.29, 0), "#4a4d4a", "y", 10)
		b.box(Vector3(0.7, 0.06, 0.06), ap + Vector3(0, -0.2, 0.36), "#3a3c3a")
		if v[3] < 0.55 and w > 3.2 and d > 3.0:
			## 물탱크 (다리 4개)
			var tp = Vector3(w * 0.22, h + 0.14, d * 0.18)
			for sx in [-0.3, 0.3]:
				for sz in [-0.3, 0.3]:
					b.beam(tp + Vector3(sx, 0, sz), tp + Vector3(sx * 0.9, 0.55, sz * 0.9), 0.03, 0.03, "#3a3c3a", 4)
			b.lathe([Vector2(0, 0.5), Vector2(0.46, 0.52), Vector2(0.48, 1.25), Vector2(0.3, 1.42), Vector2(0, 1.46)], tp, "#8a7458" if not snow else "#7c8894", Vector3.ZERO, 10)
			b.cyl(0.49, 0.49, 0.05, tp + Vector3(0, 0.9, 0), "#4a4038", "y", 10)
		else:
			## 옥상 출입구
			var hp = Vector3(w * 0.2, h + 0.75, d * 0.15)
			b.box(Vector3(1.2, 1.3, 1.2), hp, wall.lightened(0.06), Vector3.ZERO, 0.03)
			b.box(Vector3(1.35, 0.1, 1.35), hp + Vector3(0, 0.68, 0), roof.darkened(0.15))
			b.box(Vector3(0.6, 1.0, 0.06), hp + Vector3(0, -0.15, 0.6), "#2a211a")
		## 안테나
		var np = Vector3(-w * 0.32, h + 0.14, d * 0.3)
		b.beam(np, np + Vector3(0, 1.9, 0), 0.025, 0.012, "#2a2a2a", 4)
		b.beam(np + Vector3(-0.3, 1.5, 0), np + Vector3(0.3, 1.5, 0), 0.012, 0.012, "#2a2a2a", 4)
		b.beam(np + Vector3(-0.2, 1.72, 0), np + Vector3(0.2, 1.72, 0), 0.012, 0.012, "#2a2a2a", 4)
	return b.commit()


## 컨테이너 (긴 변이 X). 주름 골·문짝 잠금봉·모서리 쇠
static func _cont_mesh(c1: String) -> Mesh:
	var b = MK.new()
	var c = Color(c1)
	var w = 32 * 2 * K
	var d = 12 * 2 * K
	var h = 25 * HS
	b.box(Vector3(w - 0.06, h - 0.06, d - 0.06), Vector3(0, h / 2, 0), c.darkened(0.2))
	var cnt = int(w / 0.3)
	for i in cnt:
		var x = -w / 2 + (i + 0.5) * w / cnt
		b.box(Vector3(w / cnt * 0.6, h - 0.3, d + 0.02), Vector3(x, h / 2, 0), c, Vector3.ZERO, 0.03)
		b.box(Vector3(w / cnt * 0.6, 0.05, d - 0.1), Vector3(x, h, 0), c.lightened(0.06))
	## 테두리 틀
	for sy in [0.08, h - 0.08]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(w, 0.16, 0.1), Vector3(0, sy, sz * (d / 2 - 0.03)), c.darkened(0.32), Vector3.ZERO, 0.02)
		for sx in [-1.0, 1.0]:
			b.box(Vector3(0.1, 0.16, d), Vector3(sx * (w / 2 - 0.03), sy, 0), c.darkened(0.32), Vector3.ZERO, 0.02)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.13, h, 0.13), Vector3(sx * (w / 2 - 0.04), h / 2, sz * (d / 2 - 0.04)), c.darkened(0.32), Vector3.ZERO, 0.02)
			for sy in [0.09, h - 0.09]:
				b.box(Vector3(0.2, 0.18, 0.2), Vector3(sx * (w / 2 - 0.05), sy, sz * (d / 2 - 0.05)), "#2a2c2e", Vector3.ZERO, 0.02)
	## 문짝 (+X 끝): 잠금봉 4개와 손잡이
	b.box(Vector3(0.05, h - 0.34, d - 0.26), Vector3(w / 2 - 0.01, h / 2, 0), c.lightened(0.05))
	b.box(Vector3(0.07, h - 0.34, 0.03), Vector3(w / 2, h / 2, 0), c.darkened(0.4))
	for z in [-0.5, -0.2, 0.2, 0.5]:
		b.beam(Vector3(w / 2 + 0.04, 0.2, z), Vector3(w / 2 + 0.04, h - 0.2, z), 0.02, 0.02, "#b9bcb8", 5)
		b.box(Vector3(0.05, 0.05, 0.16), Vector3(w / 2 + 0.05, h * 0.45, z + 0.05), "#b9bcb8")
	## 옆면 표식
	for sz in [-1.0, 1.0]:
		b.box(Vector3(0.9, 0.5, 0.02), Vector3(-w * 0.22, h * 0.68, sz * (d / 2 + 0.015)), Color("#e8e4d8").lerp(c, 0.25))
		b.box(Vector3(0.5, 0.12, 0.02), Vector3(-w * 0.22, h * 0.42, sz * (d / 2 + 0.015)), Color("#e8e4d8").lerp(c, 0.25))
	return b.commit()


## 승용차 (앞이 +X)
static func _car_mesh(c1: String) -> Mesh:
	var b = MK.new()
	var c = Color(c1)
	var glass = "#1b2833"
	b.box(Vector3(2.3, 0.4, 1.06), Vector3(0, 0.44, 0), c, Vector3.ZERO, 0.1)
	b.box(Vector3(0.75, 0.1, 0.98), Vector3(0.74, 0.63, 0), c.lightened(0.06), Vector3(0, 0, -0.07), 0.04)
	b.box(Vector3(1.22, 0.36, 0.97), Vector3(-0.14, 0.8, 0), glass, Vector3.ZERO, 0.06, Vector2(0.7, 0.86))
	b.box(Vector3(0.84, 0.06, 0.84), Vector3(-0.14, 0.985, 0), c, Vector3.ZERO, 0.025)
	## 기둥 (앞·가운데·뒤)
	for sz in [-1.0, 1.0]:
		b.beam(Vector3(0.45, 0.63, sz * 0.47), Vector3(0.26, 0.97, sz * 0.41), 0.03, 0.03, c, 4)
		b.beam(Vector3(-0.14, 0.63, sz * 0.485), Vector3(-0.14, 0.97, sz * 0.415), 0.03, 0.03, c, 4)
		b.beam(Vector3(-0.74, 0.63, sz * 0.47), Vector3(-0.55, 0.97, sz * 0.41), 0.03, 0.03, c, 4)
		b.box(Vector3(0.09, 0.07, 0.12), Vector3(0.36, 0.69, sz * 0.58), c, Vector3.ZERO, 0.02)
		## 문 손잡이·옆줄
		b.box(Vector3(1.5, 0.03, 0.02), Vector3(-0.1, 0.5, sz * 0.535), c.darkened(0.25))
		for sx in [-0.72, 0.72]:
			b.cyl(0.26, 0.26, 0.2, Vector3(sx, 0.26, sz * 0.47), "#131313", "z", 12)
			b.cyl(0.13, 0.13, 0.22, Vector3(sx, 0.26, sz * 0.47), "#9aa0a6", "z", 8)
			b.box(Vector3(0.62, 0.1, 0.24), Vector3(sx, 0.53, sz * 0.45), c.darkened(0.2), Vector3.ZERO, 0.04)
		b.box(Vector3(0.05, 0.1, 0.22), Vector3(1.14, 0.52, sz * 0.36), "#f3ecc8", Vector3.ZERO, 0.02)
		b.box(Vector3(0.05, 0.09, 0.2), Vector3(-1.14, 0.54, sz * 0.38), "#b8322a", Vector3.ZERO, 0.02)
	b.box(Vector3(0.14, 0.17, 1.1), Vector3(1.12, 0.3, 0), "#26282a", Vector3.ZERO, 0.04)
	b.box(Vector3(0.14, 0.17, 1.1), Vector3(-1.12, 0.3, 0), "#26282a", Vector3.ZERO, 0.04)
	b.box(Vector3(0.04, 0.1, 0.42), Vector3(1.15, 0.5, 0), "#141516")
	return b.commit()


## 모래주머니 벽 (X 방향, 한 자루 0.5 m). 두 줄 + 위에 드문드문 한 줄
static func _sand_mesh(cnt: int, c1: String) -> Mesh:
	var b = MK.new()
	var c = Color(c1)
	var r = RandomNumberGenerator.new()
	r.seed = cnt * 77
	var L = cnt * 0.5
	for row in 3:
		var n = cnt - (row % 2)
		for i in n:
			if row == 2 and (i % 3 == 1 or i >= n - 1):
				continue
			var x = -L / 2 + (i + 0.5 + (row % 2) * 0.5) * 0.5
			var cc = c.lightened(r.randf() * 0.1) if r.randf() < 0.5 else c.darkened(r.randf() * 0.12)
			b.box(Vector3(0.5, 0.25, 0.56), Vector3(x, 0.125 + row * 0.215, (r.randf() - 0.5) * 0.06), cc, Vector3(0, (r.randf() - 0.5) * 0.14, 0), 0.1)
			b.box(Vector3(0.03, 0.2, 0.5), Vector3(x + 0.23, 0.125 + row * 0.215, 0), cc.darkened(0.22))
	return b.commit()


## 바위 (반지름 1 기준). 큰 덩어리 + 곁돌 둘. 설원이면 윗면에 눈
static func _rock_mesh(var_i: int, c1: String, snow: bool) -> Mesh:
	var b = MK.new()
	var c = Color(c1)
	var top = Color("#f0f4f7") if snow else c.lightened(0.16)
	var bot = c.darkened(0.34)
	var sd = var_i * 3.7 + 1.0
	b.blob(1.0, Vector3(0, 0.3, 0), top, bot, Vector3(1.05, [0.8, 0.95, 0.66][var_i], 0.9), sd, 0.42, 2, 1.4)
	b.blob(0.42, Vector3(0.85, 0.12, 0.45), top, bot, Vector3(1.1, 0.7, 0.9), sd + 2.0, 0.4, 1, 1.5)
	b.blob(0.3, Vector3(-0.7, 0.08, 0.75), top, bot, Vector3(1, 0.7, 1.1), sd + 5.0, 0.4, 1, 1.5)
	if var_i == 1:
		b.blob(0.55, Vector3(-0.5, 0.75, -0.3), top, bot, Vector3(0.9, 0.9, 0.8), sd + 9.0, 0.4, 1, 1.5)
	return b.commit()


## 활엽수 (잎 반지름 1 기준, 키 약 2.6)
static func _tree_mesh(var_i: int) -> Mesh:
	var b = MK.new()
	var sd = var_i * 5.3 + 2.0
	var top = [Color("#6aa24a"), Color("#5c9a52"), Color("#7aa63e")][var_i]
	var bot = [Color("#27502a"), Color("#234a30"), Color("#345522")][var_i]
	b.lathe([Vector2(0.24, 0.0), Vector2(0.15, 0.14), Vector2(0.11, 0.9), Vector2(0.09, 1.75)], Vector3.ZERO, "#4a3626", Vector3.ZERO, 7, ["#3e2c1f", "#4a3626", "#553f2c"])
	for i in 3:
		var a = i / 3.0 * TAU + sd
		b.beam(Vector3(0, 1.1 + i * 0.12, 0), Vector3(cos(a) * 0.5, 1.75, sin(a) * 0.5), 0.05, 0.03, "#4a3626", 5)
	var n = 5 + var_i % 2
	for i in n:
		var a = i / float(n) * TAU + sd
		var rr = 0.56 + 0.1 * sin(i * 2.3 + sd)
		b.blob(rr, Vector3(cos(a) * 0.52, 1.8 + (i % 2) * 0.28, sin(a) * 0.52), top, bot, Vector3(1.1, 0.85, 1.1), sd + i * 1.7, 0.3, 2, 1.8)
	b.blob(0.68, Vector3(0, 2.3, 0), top.lightened(0.06), bot, Vector3(1.1, 0.8, 1.1), sd + 20.0, 0.3, 2, 1.8)
	return b.commit()


## 침엽수 (아래 가지 반지름 1 기준, 키 약 2.4). 들쭉날쭉한 치마 4단
static func _pine_mesh(var_i: int, snow: bool) -> Mesh:
	var b = MK.new()
	b.lathe([Vector2(0.15, 0.0), Vector2(0.1, 0.2), Vector2(0.06, 1.2)], Vector3.ZERO, "#4a3626", Vector3.ZERO, 6)
	var tiers = [[1.0, 0.42, 1.28], [0.8, 0.95, 1.72], [0.6, 1.4, 2.08], [0.38, 1.8, 2.42]]
	var seg = 9 + var_i * 2
	for ti in tiers.size():
		var R: float = tiers[ti][0]
		var y0: float = tiers[ti][1]
		var y1: float = tiers[ti][2]
		var ca = Color("#2f5f42") if ti % 2 == 0 else Color("#377049")
		if var_i == 1:
			ca = ca.lerp(Color("#3d6a38"), 0.5)
		var apex = Vector3(0, y1, 0)
		var pts: Array = []
		for j in seg * 2:
			var a = j / float(seg * 2) * TAU + ti * 0.4
			var rr = R if j % 2 == 0 else R * 0.72
			pts.append(Vector3(cos(a) * rr, y0 - (0.1 if j % 2 == 0 else 0.0), sin(a) * rr))
		for j in pts.size():
			var p0: Vector3 = pts[j]
			var p1: Vector3 = pts[(j + 1) % pts.size()]
			var out = (p0 + p1) * 0.5 + Vector3(0, 0.4, 0)
			b.tri(p0, p1, apex, ca if j % 2 == 0 else ca.darkened(0.14), out)
			b.tri(p0, p1, Vector3(0, y0 + 0.12, 0), Color("#1c3a2a"), Vector3.DOWN)
			if snow:
				## 눈: 각 단의 위쪽 절반
				var q0 = apex.lerp(p0, 0.58) + Vector3(0, 0.02, 0)
				var q1 = apex.lerp(p1, 0.58) + Vector3(0, 0.02, 0)
				b.tri(q0, q1, apex + Vector3(0, 0.02, 0), Color("#eef2f5") if j % 2 == 0 else Color("#d6dee6"), out)
	return b.commit()


## 야자수 (잎 길이 1 기준, 키 약 2.25). 휘어진 줄기 + 늘어진 잎
static func _palm_mesh(var_i: int) -> Mesh:
	var b = MK.new()
	var lean = 0.32 if var_i == 0 else -0.2
	var T = func(t: float) -> Vector3: return Vector3(lean * t * t * 2.0, 2.25 * t, 0.12 * t)
	for i in 7:
		var a: Vector3 = T.call(i / 7.0)
		var c: Vector3 = T.call((i + 1) / 7.0)
		var r0 = lerpf(0.14, 0.085, i / 7.0)
		b.beam(a, c, r0 + 0.015, r0 - 0.005, "#7a6040" if i % 2 == 0 else "#6a5236", 7)
	var top: Vector3 = T.call(1.0)
	b.sphere(0.14, top, "#5a4a2e", Vector3.ONE, 8, 5)
	for i in 3:
		var a = i / 3.0 * TAU
		b.sphere(0.075, top + Vector3(cos(a) * 0.12, -0.1, sin(a) * 0.12), "#4a3a22", Vector3.ONE, 6, 4)
	var nf = 9
	for i in nf:
		var a = i / float(nf) * TAU + var_i
		var dir = Vector3(cos(a), 0, sin(a))
		var side = Vector3(-sin(a), 0, cos(a))
		var L = 1.0 + 0.12 * sin(i * 3.1)
		var droop = 0.75 + 0.25 * sin(i * 1.7 + 1.0)
		var col = Color("#6f9440") if i % 2 == 0 else Color("#567a30")
		var prev_c = top
		var prev_w = 0.04
		for j in range(1, 7):
			var u = j / 6.0
			var cen = top + dir * (L * u) + Vector3(0, 0.38 * sin(u * PI * 0.85) - droop * u * u, 0)
			var wd = 0.26 * sin(u * PI) + 0.03
			var cc = col.darkened(u * 0.25)
			## 가운데가 솟은 V자 단면: 왼쪽 판 + 오른쪽 판
			b.quad(prev_c, cen, cen + side * wd - Vector3(0, 0.07, 0), prev_c + side * prev_w - Vector3(0, 0.07, 0), cc, Vector3.UP, Transform3D.IDENTITY, true)
			b.quad(prev_c, cen, cen - side * wd - Vector3(0, 0.07, 0), prev_c - side * prev_w - Vector3(0, 0.07, 0), cc.darkened(0.08), Vector3.UP, Transform3D.IDENTITY, true)
			prev_c = cen
			prev_w = wd
	return b.commit()


## ---------- 부서진 엄폐물 ----------
## 폭발로 부서진 뒤 남는 모습. 건물은 무너진 벽과 잔해 더미, 차·컨테이너는 그을린 차체, 나무는 그루터기
static func build_wreck(n: Node3D, k: Dictionary) -> void:
	var v: Array = k.v
	match k.kind:
		"bld":
			var b = MK.new()
			var w: float = k.hw * 2 * K
			var d: float = k.hh * 2 * K
			var wall = Color(str(k.c2)).darkened(0.25)
			var r = RandomNumberGenerator.new()
			r.seed = int(k.x * 13 + k.y * 7)
			b.box(Vector3(w * 0.96, 0.3, d * 0.96), Vector3(0, 0.15, 0), wall.darkened(0.3))
			## 들쭉날쭉 남은 벽
			for side in 4:
				var span = w if side < 2 else d
				var sg = -1.0 if side % 2 == 0 else 1.0
				var cnt = maxi(2, int(span / 1.3))
				for i in cnt:
					if r.randf() < 0.3:
						continue
					var t = -span / 2 + (i + 0.5) * span / cnt
					var hh = 0.4 + r.randf() * r.randf() * 2.6
					var pos = Vector3(t, hh / 2, sg * d * 0.47) if side < 2 else Vector3(sg * w * 0.47, hh / 2, t)
					var sz = Vector3(span / cnt * 0.98, hh, 0.22) if side < 2 else Vector3(0.22, hh, span / cnt * 0.98)
					b.box(sz, pos, wall if r.randf() < 0.6 else wall.lightened(0.1), Vector3(0, 0, (r.randf() - 0.5) * 0.12))
			## 안쪽 잔해: 기운 판과 덩어리
			for i in maxi(5, int(w * d * 0.5)):
				var px = (r.randf() - 0.5) * w * 0.8
				var pz = (r.randf() - 0.5) * d * 0.8
				if r.randf() < 0.45:
					b.box(Vector3(0.8 + r.randf() * 1.2, 0.14, 0.6 + r.randf() * 1.0), Vector3(px, 0.35 + r.randf() * 0.5, pz), wall.darkened(0.1), Vector3((r.randf() - 0.5) * 0.9, r.randf() * 3.0, (r.randf() - 0.5) * 0.9))
				else:
					b.blob(0.3 + r.randf() * 0.4, Vector3(px, 0.3, pz), wall.lightened(0.05), wall.darkened(0.4), Vector3(1.2, 0.7, 1.0), i * 1.3, 0.4, 1, 1.5)
			b.beam(Vector3(-w * 0.2, 0.3, d * 0.1), Vector3(w * 0.25, 1.4, -d * 0.2), 0.05, 0.05, "#2a2a2a", 4)
			MK.inst(n, b.commit())
		"cont":
			var mi = MK.inst(n, MK.cached("cont_#1e1c1a", func(): return _cont_mesh("#2a2622")))
			mi.rotation = Vector3(0.1, (PI / 2 if k.hw < k.hh else 0.0) + 0.12, 0.16)
			mi.scale = Vector3(1.0, 0.72, 1.0)
		"car":
			var mi = MK.inst(n, MK.cached("car_#1c1a18", func(): return _car_mesh("#1c1a18")))
			mi.rotation = Vector3(0.06, (0.0 if k.hw > k.hh else PI / 2) + 0.3, -0.1)
			mi.scale = Vector3(1.0, 0.82, 1.0)
		"sand":
			var cnt = maxi(2, int((k.hw if k.hw > k.hh else k.hh) * 2 * K / 0.5))
			var c1: String = k.c1
			var mi = MK.inst(n, MK.cached("sand_%d_%s" % [cnt, c1], func(): return _sand_mesh(cnt, c1)))
			mi.scale = Vector3(1.15, 0.35, 1.5)
			mi.rotation.y = (0.0 if k.hw > k.hh else PI / 2) + 0.2
		"rock":
			var c1: String = k.c1
			var mi = MK.inst(n, MK.cached("rock_2_%s_false" % c1, func(): return _rock_mesh(2, c1, false)))
			mi.scale = Vector3.ONE * k.r * K * 0.5
			mi.rotation.y = v[0] * TAU + 1.0
		_:
			## 나무: 그을린 그루터기 + 쓰러진 줄기
			var mi = MK.inst(n, MK.cached("stump", func():
				var b = MK.new()
				b.lathe([Vector2(0.24, 0.0), Vector2(0.15, 0.14), Vector2(0.13, 0.38), Vector2(0.0, 0.42)], Vector3.ZERO, "#2e2218", Vector3.ZERO, 7)
				b.beam(Vector3(0.25, 0.14, 0.1), Vector3(1.9, 0.2, 0.5), 0.12, 0.08, "#3a2a1c", 6, true)
				b.beam(Vector3(1.2, 0.2, 0.34), Vector3(1.7, 0.5, -0.2), 0.05, 0.03, "#3a2a1c", 5)
				b.blob(0.4, Vector3(2.0, 0.25, 0.5), "#3e4a2a", "#22281a", Vector3(1.2, 0.6, 1.0), 3.0, 0.35, 1, 1.6)
				return b.commit()))
			mi.scale = Vector3.ONE * k.vr * K
			mi.rotation.y = v[0] * TAU


## ---------- 시설 주변 설비 ----------
## 임무 구조물 하나만 덩그러니 있지 않게, 종류에 맞는 설비를 둘레에 깐다 (길을 막고, 큰 것은 탄환·시야도 막는다).
## [종류, 가로 치우침, 세로 치우침, 방향(0=동, 1=남, 2=서, 3=북)]
const SITE := {
	aa = [["patriot", 96, -30, 3], ["patriot", -92, -44, 3], ["radar", 6, -108, 3], ["truck", -70, 84, 0], ["crates", 64, 70, 0], ["tent", 118, 58, 1]],
	nest = [["tent", 104, -6, 1], ["tent", -104, 8, 1], ["tower", 0, -100, 0], ["truck", 78, 92, 0], ["crates", -70, 80, 0], ["crates", 96, -84, 0]],
	jam = [["truck", 92, 24, 1], ["tent", -92, -18, 1], ["radar", 0, -104, 3], ["crates", 60, -70, 0], ["tower", -78, 84, 0]],
	fac = [["truck", 132, 78, 0], ["truck", 132, 20, 0], ["crates", -122, 50, 0], ["crates", -128, -10, 0], ["tower", -112, -86, 0], ["patriot", 40, -118, 3]],
	term = [["tent", 104, -34, 1], ["radar", -8, -108, 3], ["crates", -92, 34, 0]],
	cap = [["tent", 112, 40, 1], ["truck", -112, 30, 1], ["crates", 60, -96, 0]],
}
## 반폭·반깊이·높이(게임 단위). 높이 16 이상이면 탄환과 시야를 막는다
const SITE_BOX := {patriot = [30.0, 13.0, 24.0], radar = [20.0, 14.0, 22.0], tent = [25.0, 20.0, 20.0], truck = [35.0, 15.0, 22.0]}


static func dress_sites(root: Node3D, m: Dictionary) -> void:
	var r = RandomNumberGenerator.new()
	r.seed = m.seed + 91
	for o in m.objs:
		var q = r.randi() % 4
		for it in SITE.get(o.type, []):
			var kind: String = it[0]
			## 배치 전체를 90도 단위로 돌려 지점마다 다르게 보이게 한다
			var dx: float = it[1]
			var dy: float = it[2]
			for i in q:
				var t = dx
				dx = -dy
				dy = t
			var rot: int = (it[3] + q) % 4
			var x = clampf(o.x + dx, 50, WORLD - 50)
			var y = clampf(o.y + dy, 50, WORLD - 50)
			var n = Node3D.new()
			n.position = p3(x, y)
			n.rotation.y = -rot * PI / 2
			root.add_child(n)
			MK.inst(n, MK.cached("site_" + kind, func(): return _site_mesh(kind)))
			var c: Dictionary
			if SITE_BOX.has(kind):
				var sb: Array = SITE_BOX[kind]
				var odd = rot % 2 == 1
				c = {kind = "site", x = x, y = y, hw = sb[1] if odd else sb[0], hh = sb[0] if odd else sb[1], h = sb[2]}
			else:
				c = {kind = "site", x = x, y = y, r = 13.0, h = 10.0}
			m.rg[int(y / 100) * 30 + int(x / 100)].append(c)


static func _wheels(b, xs: Array, y: float, z: float, r: float) -> void:
	for x in xs:
		for s in [-1.0, 1.0]:
			b.cyl(r, r, 0.32, Vector3(x, y, s * z), "#131313", "z", 10)
			b.cyl(r * 0.5, r * 0.5, 0.34, Vector3(x, y, s * z), "#4a4f41", "z", 8)


static func _site_mesh(kind: String) -> Mesh:
	var b = MK.new()
	var od = "#5a604e"
	var dk = "#444a3c"
	match kind:
		"patriot":
			## 지대공 미사일 발사대: 트레일러 + 받침 다리 + 치켜든 4연장 발사함
			b.box(Vector3(3.6, 0.24, 1.5), Vector3(0, 0.78, 0), dk, Vector3.ZERO, 0.04)
			_wheels(b, [-1.2, -0.5], 0.4, 0.66, 0.4)
			for sx in [-1.6, 1.6]:
				for sz in [-0.95, 0.95]:
					b.beam(Vector3(sx * 0.9, 0.75, sz * 0.7), Vector3(sx, 0.06, sz), 0.05, 0.05, "#2b2e28", 5)
					b.cyl(0.16, 0.18, 0.06, Vector3(sx, 0.03, sz), "#2b2e28", "y", 8)
			b.box(Vector3(0.9, 0.7, 1.3), Vector3(-1.3, 1.25, 0), od, Vector3.ZERO, 0.06)
			b.cyl(0.55, 0.6, 0.2, Vector3(0.3, 1.0, 0), dk, "y", 12)
			b.beam(Vector3(0.9, 1.0, 0.4), Vector3(1.0, 1.9, 0.4), 0.06, 0.05, dk, 5)
			b.beam(Vector3(0.9, 1.0, -0.4), Vector3(1.0, 1.9, -0.4), 0.06, 0.05, dk, 5)
			var keep = b.base
			b.base = Transform3D(Basis.from_euler(Vector3(0, 0, 0.62)), Vector3(0.45, 2.0, 0))
			b.box(Vector3(2.9, 1.0, 1.36), Vector3.ZERO, "#6b705e", Vector3.ZERO, 0.04)
			for sy in [-0.25, 0.25]:
				for sz in [-0.34, 0.34]:
					b.box(Vector3(0.05, 0.42, 0.58), Vector3(1.46, sy, sz), "#2e3129")
					b.box(Vector3(2.92, 0.03, 0.03), Vector3(0, sy, sz * 2.0), dk)
			b.box(Vector3(2.95, 0.05, 1.4), Vector3(0, 0, 0), dk)
			b.box(Vector3(0.12, 1.04, 1.4), Vector3(-0.9, 0, 0), dk)
			b.box(Vector3(0.12, 1.04, 1.4), Vector3(0.7, 0, 0), dk)
			b.base = keep
		"radar":
			## 위상배열 레이더: 차대 + 장비함 + 비스듬히 세운 판
			b.box(Vector3(2.4, 0.28, 1.6), Vector3(0, 0.7, 0), dk, Vector3.ZERO, 0.04)
			_wheels(b, [-0.75, 0.75], 0.38, 0.7, 0.38)
			b.box(Vector3(1.0, 0.9, 1.4), Vector3(-0.6, 1.3, 0), od, Vector3.ZERO, 0.06)
			b.box(Vector3(0.24, 2.0, 2.3), Vector3(0.5, 2.0, 0), "#70766a", Vector3(0, 0, 0.3), 0.05)
			b.box(Vector3(0.05, 1.7, 2.0), Vector3(0.63, 2.04, 0), "#8d9488", Vector3(0, 0, 0.3))
			b.beam(Vector3(0.1, 0.85, 0), Vector3(0.3, 1.6, 0), 0.09, 0.07, dk, 6)
			b.beam(Vector3(-1.0, 1.75, 0.5), Vector3(-1.05, 3.3, 0.52), 0.015, 0.008, "#1c1e1a", 4)
			b.glow = true
			b.box(Vector3(0.03, 0.08, 0.3), Vector3(-1.11, 1.5, -0.3), "#7fd0ff")
			b.glow = false
		"tent":
			## 군용 천막: 맞배 지붕 + 낮은 벽 + 출입구
			var w = 1.5
			var d = 1.2
			var c1 = Color("#5d6248")
			for sg in [-1.0, 1.0]:
				b.quad(Vector3(-w, 1.0, sg * d), Vector3(w, 1.0, sg * d), Vector3(w, 1.95, 0), Vector3(-w, 1.95, 0), c1 if sg > 0 else c1.darkened(0.1), Vector3(0, 0.6, sg))
				b.quad(Vector3(-w, 0, sg * d), Vector3(w, 0, sg * d), Vector3(w, 1.0, sg * d), Vector3(-w, 1.0, sg * d), c1.darkened(0.2), Vector3(0, 0, sg))
				b.quad(Vector3(sg * w, 0, -d), Vector3(sg * w, 0, d), Vector3(sg * w, 1.0, d), Vector3(sg * w, 1.0, -d), c1.darkened(0.14), Vector3(sg, 0, 0))
				b.tri(Vector3(sg * w, 1.0, -d), Vector3(sg * w, 1.0, d), Vector3(sg * w, 1.95, 0), c1.darkened(0.14), Vector3(sg, 0, 0))
				for sx in [-1.0, 1.0]:
					b.beam(Vector3(sx * w, 1.0, sg * d), Vector3(sx * (w + 0.5), 0.02, sg * (d + 0.6)), 0.01, 0.01, "#2a2a26", 3)
			b.box(Vector3(0.03, 1.3, 0.8), Vector3(w + 0.01, 0.65, 0), "#14150f")
			b.box(Vector3(3.1, 0.06, 0.1), Vector3(0, 1.96, 0), c1.darkened(0.3))
		"tower":
			## 감시탑: 다리 넷 + 난간 달린 단 + 지붕 + 탐조등
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					b.beam(Vector3(sx * 0.75, 0, sz * 0.75), Vector3(sx * 0.6, 3.3, sz * 0.6), 0.06, 0.05, "#4a3a28", 5)
					b.beam(Vector3(sx * 0.6, 3.4, sz * 0.6), Vector3(sx * 0.6, 4.7, sz * 0.6), 0.04, 0.04, "#4a3a28", 4)
			for y in [1.1, 2.2]:
				b.beam(Vector3(-0.7, y, -0.7), Vector3(0.7, y + 0.6, -0.7), 0.03, 0.03, "#3e3022", 4)
				b.beam(Vector3(0.7, y, 0.7), Vector3(-0.7, y + 0.6, 0.7), 0.03, 0.03, "#3e3022", 4)
			b.box(Vector3(1.7, 0.12, 1.7), Vector3(0, 3.35, 0), "#5a4a34", Vector3.ZERO, 0.02)
			for sg in [-1.0, 1.0]:
				b.box(Vector3(1.7, 0.75, 0.07), Vector3(0, 3.8, sg * 0.82), "#55603a")
				b.box(Vector3(0.07, 0.75, 1.7), Vector3(sg * 0.82, 3.8, 0), "#55603a")
			b.box(Vector3(2.1, 0.1, 2.1), Vector3(0, 4.78, 0), "#3a3e33", Vector3(0, 0, 0.08), 0.02)
			b.beam(Vector3(0.95, 0, 0.3), Vector3(0.86, 3.3, 0.3), 0.025, 0.025, "#2a2a26", 4)
			b.beam(Vector3(0.95, 0, -0.3), Vector3(0.86, 3.3, -0.3), 0.025, 0.025, "#2a2a26", 4)
			for i in 7:
				b.beam(Vector3(0.94 - i * 0.012, 0.4 + i * 0.44, -0.3), Vector3(0.94 - i * 0.012, 0.4 + i * 0.44, 0.3), 0.02, 0.02, "#2a2a26", 3)
			b.cyl(0.16, 0.2, 0.26, Vector3(0.6, 4.25, 0.6), "#22241f", "x", 8)
			b.glow = true
			b.cyl(0.17, 0.17, 0.03, Vector3(0.74, 4.25, 0.6), "#fff0c0", "x", 8)
			b.glow = false
		"truck":
			## 군용 화물차: 운전석 + 천막 씌운 적재함 + 바퀴 여섯
			b.box(Vector3(4.2, 0.3, 1.5), Vector3(0, 0.75, 0), "#2b2e28")
			_wheels(b, [1.35, -0.6, -1.5], 0.45, 0.72, 0.45)
			b.box(Vector3(1.25, 1.2, 1.66), Vector3(1.35, 1.5, 0), od, Vector3.ZERO, 0.1, Vector2(0.9, 0.94))
			b.box(Vector3(0.06, 0.5, 1.4), Vector3(1.96, 1.72, 0), "#16232b")
			for s in [-1.0, 1.0]:
				b.box(Vector3(0.6, 0.42, 0.04), Vector3(1.4, 1.72, s * 0.82), "#16232b")
				b.box(Vector3(0.08, 0.12, 0.2), Vector3(2.08, 1.0, s * 0.6), "#e8e2c0")
			b.box(Vector3(0.2, 0.3, 1.7), Vector3(2.08, 0.72, 0), "#23261f", Vector3.ZERO, 0.04)
			b.box(Vector3(2.7, 1.35, 1.7), Vector3(-0.72, 1.6, 0), "#6b6a4c", Vector3.ZERO, 0.22)
			b.box(Vector3(2.74, 0.5, 1.72), Vector3(-0.72, 1.1, 0), dk)
			for x in [-1.7, -0.72, 0.26]:
				b.box(Vector3(0.06, 1.38, 1.74), Vector3(x, 1.6, 0), "#57563e")
		_:
			## 탄약 상자 더미 + 드럼통
			b.box(Vector3(1.0, 0.6, 0.7), Vector3(-0.2, 0.3, -0.1), "#56603a", Vector3(0, 0.2, 0), 0.04)
			b.box(Vector3(0.9, 0.55, 0.65), Vector3(-0.15, 0.88, -0.1), "#4b5432", Vector3(0, -0.15, 0), 0.04)
			b.box(Vector3(0.8, 0.5, 0.6), Vector3(0.7, 0.25, 0.5), "#6b5a3a", Vector3(0, 0.6, 0), 0.04)
			b.box(Vector3(0.7, 0.06, 0.1), Vector3(-0.2, 0.61, 0.2), "#c8a030")
			for q in [[0.75, -0.45, "#3f6a8a"], [0.2, 0.75, "#a8322a"]]:
				b.cyl(0.25, 0.25, 0.72, Vector3(q[0], 0.36, q[1]), q[2], "y", 10)
				b.cyl(0.26, 0.26, 0.04, Vector3(q[0], 0.5, q[1]), "#22241f", "y", 10)
	return b.commit()


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
		"jam":
			## 미니맵 교란기: 발전기 + 제어함 + 돛대 위에서 도는 방사판
			var b = MK.new()
			b.cyl(1.7, 1.8, 0.16, Vector3(0, 0.08, 0), "#6e7068", "y", 12)
			b.box(Vector3(1.5, 0.9, 0.95), Vector3(-0.75, 0.62, 0.45), "#4f5a44", Vector3.ZERO, 0.08)
			b.box(Vector3(0.5, 0.06, 0.7), Vector3(-0.75, 1.1, 0.45), "#2b2e28")
			b.cyl(0.07, 0.07, 0.5, Vector3(-1.3, 1.3, 0.2), "#1e1f1c", "y", 6)
			b.box(Vector3(0.85, 1.6, 0.7), Vector3(0.75, 0.96, -0.35), "#33363c", Vector3.ZERO, 0.06)
			b.box(Vector3(0.6, 0.5, 0.04), Vector3(0.75, 1.3, 0.01), "#15171a")
			b.glow = true
			for i in 3:
				b.box(Vector3(0.12, 0.06, 0.05), Vector3(0.55 + i * 0.2, 1.38, 0.03), "#c070ff")
			b.box(Vector3(0.5, 0.05, 0.05), Vector3(0.75, 1.2, 0.03), "#62d0f0")
			b.glow = false
			b.lathe([Vector2(0.22, 0.16), Vector2(0.12, 0.5), Vector2(0.08, 3.0), Vector2(0.06, 5.3)], Vector3.ZERO, "#2a2d30", Vector3.ZERO, 8)
			for y in [3.0, 4.1]:
				b.beam(Vector3(-0.9, y, 0), Vector3(0.9, y, 0), 0.03, 0.03, "#8d959c", 5)
				for x in [-0.9, -0.45, 0.45, 0.9]:
					b.beam(Vector3(x, y - 0.35, 0), Vector3(x, y + 0.55, 0), 0.02, 0.012, "#c8ced4", 4)
			for i in 3:
				var a = i / 3.0 * TAU + 0.3
				b.beam(Vector3(0, 4.6, 0), Vector3(cos(a) * 2.3, 0.1, sin(a) * 2.3), 0.012, 0.012, "#1a1c1e", 3)
			for i in 7:
				var a = i / 7.0 * TAU
				b.box(Vector3(0.75, 0.3, 0.5), Vector3(cos(a) * 2.2, 0.17, sin(a) * 2.2), "#a8996f" if i % 2 else "#9a8c66", Vector3(0, -a + PI / 2, 0), 0.11)
			MK.inst(live, b.commit())
			var spin = Node3D.new()
			spin.name = "Spin"
			spin.position = Vector3(0, 5.3, 0)
			live.add_child(spin)
			var sb = MK.new()
			sb.box(Vector3(1.5, 0.7, 0.1), Vector3(0, 0.4, 0.12), "#d9dde2", Vector3.ZERO, 0.03)
			sb.box(Vector3(1.3, 0.5, 0.12), Vector3(0, 0.4, 0.02), "#5a6068")
			for x in [-0.45, 0.0, 0.45]:
				sb.lathe([Vector2(0.03, 0.0), Vector2(0.16, 0.3)], Vector3(x, 0.4, 0.17), "#7a40c0", Vector3(PI / 2, 0, 0), 8)
			sb.cyl(0.1, 0.1, 0.2, Vector3(0, 0.05, 0), "#2a2d30", "y", 8)
			MK.inst(spin, sb.commit())
			var lamp = ML.sph(live, 0.14, "#c070ff", Vector3(0, 6.25, 0), Vector3.ONE, ML.mat("#c070ff", 3.5))
			lamp.name = "Lamp"
		"fac":
			## 군수공장: 톱니 지붕 공장동 + 굴뚝 둘 + 연료 탱크 + 적재 상자
			var b = MK.new()
			var wall = Color("#70756f")
			b.box(Vector3(6.4, 0.3, 4.6), Vector3(0, 0.15, 0), "#55584f", Vector3.ZERO, 0.04)
			b.box(Vector3(6.0, 2.7, 4.2), Vector3(0, 1.6, 0), wall, Vector3.ZERO, 0.05)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					b.box(Vector3(0.3, 2.9, 0.3), Vector3(sx * 2.95, 1.6, sz * 2.05), wall.darkened(0.25))
			b.box(Vector3(6.1, 0.14, 4.3), Vector3(0, 0.95, 0), wall.darkened(0.3))
			## 톱니 지붕 3칸 (비탈 + 채광창)
			for i in 3:
				var x0 = -3.0 + i * 2.0
				b.quad(Vector3(x0, 2.95, -2.1), Vector3(x0, 2.95, 2.1), Vector3(x0 + 2.0, 3.85, 2.1), Vector3(x0 + 2.0, 3.85, -2.1), "#4a4f55", Vector3(-0.4, 1, 0))
				b.glow = true
				b.quad(Vector3(x0 + 2.0, 2.95, -2.0), Vector3(x0 + 2.0, 2.95, 2.0), Vector3(x0 + 2.0, 3.8, 2.0), Vector3(x0 + 2.0, 3.8, -2.0), "#ffc878", Vector3(1, 0, 0))
				b.glow = false
				for sz in [-1.0, 1.0]:
					b.tri(Vector3(x0, 2.95, sz * 2.1), Vector3(x0 + 2.0, 2.95, sz * 2.1), Vector3(x0 + 2.0, 3.85, sz * 2.1), wall.darkened(0.12), Vector3(0, 0, sz))
			## 정면 셔터 + 경고 줄무늬 + 창
			b.box(Vector3(2.2, 2.0, 0.1), Vector3(-1.2, 1.3, 2.12), "#2b2e32")
			for i in 6:
				b.box(Vector3(2.2, 0.05, 0.12), Vector3(-1.2, 0.5 + i * 0.32, 2.13), "#3d4147")
			for i in 5:
				b.box(Vector3(0.24, 0.16, 0.13), Vector3(-2.1 + i * 0.45, 2.38, 2.13), "#f2c21b" if i % 2 == 0 else "#1c1d1e")
			b.glow = true
			for i in 3:
				b.box(Vector3(0.7, 0.5, 0.1), Vector3(0.8 + i * 0.85, 1.9, 2.12), "#ffd596")
			b.glow = false
			b.box(Vector3(1.6, 0.9, 0.06), Vector3(1.65, 0.9, 2.13), "#a8322a")
			## 굴뚝 (붉고 흰 띠)
			for cx in [-2.2, -1.2]:
				b.lathe([Vector2(0.42, 2.9), Vector2(0.36, 3.6), Vector2(0.33, 4.3), Vector2(0.3, 5.0), Vector2(0.28, 5.6), Vector2(0.2, 5.6)], Vector3(cx, 0, -1.3), "#8a8d88", Vector3.ZERO, 10, ["#8a8d88", "#b8322a", "#e4e6e2", "#b8322a", "#2a2a2a"])
			## 연료 탱크 + 배관
			b.cyl(0.75, 0.75, 2.6, Vector3(3.9, 1.0, -0.6), "#8b8f86", "z", 12)
			b.sphere(0.75, Vector3(3.9, 1.0, 0.7), "#8b8f86", Vector3(1, 1, 0.45), 12, 5)
			b.sphere(0.75, Vector3(3.9, 1.0, -1.9), "#8b8f86", Vector3(1, 1, 0.45), 12, 5)
			b.box(Vector3(0.9, 0.12, 0.3), Vector3(3.9, 1.0, -0.6), "#b8322a")
			for z in [-1.4, 0.2]:
				b.box(Vector3(1.3, 0.3, 0.25), Vector3(3.9, 0.15, z), "#3a3c3a")
			b.beam(Vector3(3.2, 1.6, -0.6), Vector3(3.0, 2.2, -0.6), 0.07, 0.07, "#c8a030", 6)
			## 적재 상자·드럼통
			b.box(Vector3(0.9, 0.7, 0.9), Vector3(1.5, 0.45, 3.0), "#56603a", Vector3(0, 0.3, 0), 0.04)
			b.box(Vector3(0.8, 0.6, 0.8), Vector3(2.4, 0.4, 2.9), "#6b5a3a", Vector3(0, -0.2, 0), 0.04)
			b.box(Vector3(0.7, 0.55, 0.7), Vector3(1.8, 1.05, 3.0), "#56603a", Vector3(0, 0.6, 0), 0.04)
			for i in 3:
				b.cyl(0.26, 0.26, 0.75, Vector3(-2.9 + i * 0.6, 0.48, 2.9), "#3f6a8a" if i != 1 else "#a8322a", "y", 10)
			MK.inst(live, b.commit())
	## 파괴 후 잔해
	for i in 5:
		var a = i * 1.3
		ML.box(dead, Vector3(0.6 + (i % 3) * 0.3, 0.4 + (i % 2) * 0.3, 0.5 + (i % 2) * 0.4), "#5d605a", Vector3(cos(a) * 1.2, 0.2, sin(a) * 0.9), Vector3(0, a, 0.1 * i))
	n.position = p3(o.x, o.y)
	return n
