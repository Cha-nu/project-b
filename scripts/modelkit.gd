extends RefCounted
## 모델 빌더: 여러 도형을 정점 색과 함께 메시 하나로 합친다.
## 모서리를 깎은 상자, 회전체(lathe), 끝이 가늘어지는 막대, 노이즈로 울퉁불퉁한 덩어리를 지원한다.
## 부품 수십 개짜리 모델이 드로우 콜 하나가 되므로 MeshInstance3D를 부품마다 만드는 것보다 가볍다.
##
##   var b = MK.new()
##   b.box(Vector3(1, 1, 1), Vector3(0, 0.5, 0), "#808080", Vector3.ZERO, 0.08)
##   var mesh = b.commit()

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _gv := PackedVector3Array()
var _gn := PackedVector3Array()
var _gc := PackedColorArray()
## true인 동안 추가한 도형은 조명을 받지 않는 발광 면(불 켜진 창 등)으로 들어간다
var glow := false
## 비어 있지 않으면 넘겨받은 색 대신 이 색들로 얼룩무늬(위장복)를 칠한다
var camo: Array = []
var camo_freq := 7.5
## 모든 도형에 앞서 적용되는 변환 (부품 묶음을 통째로 옮기거나 돌릴 때)
var base := Transform3D.IDENTITY

static var _mat: StandardMaterial3D
static var _mat_o: StandardMaterial3D
static var _mat_g: StandardMaterial3D
static var _noise: FastNoiseLite
static var _cache := {}


static func mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.9
	return _mat


## 외곽선이 붙는 버전 (캐릭터·차량)
static func mat_outlined(width := 0.011) -> StandardMaterial3D:
	if _mat_o == null:
		_mat_o = mat().duplicate()
		var o := StandardMaterial3D.new()
		o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		o.albedo_color = Color(0.035, 0.04, 0.06)
		o.cull_mode = BaseMaterial3D.CULL_FRONT
		o.grow = true
		o.grow_amount = width
		_mat_o.next_pass = o
	return _mat_o


static func mat_glow() -> StandardMaterial3D:
	if _mat_g == null:
		_mat_g = StandardMaterial3D.new()
		_mat_g.vertex_color_use_as_albedo = true
		_mat_g.vertex_color_is_srgb = true
		_mat_g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mat_g


## 같은 key의 메시는 한 번만 만든다
static func cached(key: String, make: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func inst(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, outlined := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if outlined:
		mi.material_override = mat_outlined()
	parent.add_child(mi)
	return mi


static func _nz() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_noise.frequency = 1.0
	return _noise


static func col(c) -> Color:
	return c if c is Color else Color(str(c))


static func xf(pos: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)


func commit() -> ArrayMesh:
	var m := ArrayMesh.new()
	if _v.size() > 0:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = _v
		a[Mesh.ARRAY_NORMAL] = _n
		a[Mesh.ARRAY_COLOR] = _c
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(m.get_surface_count() - 1, mat())
	if _gv.size() > 0:
		var g := []
		g.resize(Mesh.ARRAY_MAX)
		g[Mesh.ARRAY_VERTEX] = _gv
		g[Mesh.ARRAY_NORMAL] = _gn
		g[Mesh.ARRAY_COLOR] = _gc
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g)
		m.surface_set_material(m.get_surface_count() - 1, mat_glow())
	return m


## ---------- 삼각형 넣기 ----------
## 감는 방향은 법선을 보고 알아서 맞춘다 (Godot는 시계 방향이 앞면)
func _tri(t: Transform3D, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, cl: Color) -> void:
	if camo.size() > 0:
		## 삼각형 중심의 공간 노이즈로 색을 고른다 (이웃한 면끼리 얼룩이 이어진다)
		var ce := (t * ((a + b + c) / 3.0)) * camo_freq
		var nz := _nz()
		var nv := nz.get_noise_3d(ce.x, ce.y, ce.z) * 0.5 + 0.5 + nz.get_noise_3d(ce.x * 2.7 + 9.0, ce.y * 2.7, ce.z * 2.7) * 0.22
		cl = col(camo[clampi(int(nv * camo.size()), 0, camo.size() - 1)])
	var tt := base * t
	var pa := tt * a
	var pb := tt * b
	var pc := tt * c
	var qa := (tt.basis * na).normalized()
	var qb := (tt.basis * nb).normalized()
	var qc := (tt.basis * nc).normalized()
	var flip := (pb - pa).cross(pc - pa).dot(qa + qb + qc) > 0.0
	if flip:
		var sp := pb
		pb = pc
		pc = sp
		var sq := qb
		qb = qc
		qc = sq
	## (멤버 배열에 바로 넣는다. 지역 변수로 받으면 넣을 때마다 통째로 복사된다)
	if glow:
		_gv.append(pa); _gv.append(pb); _gv.append(pc)
		_gn.append(qa); _gn.append(qb); _gn.append(qc)
		_gc.append(cl); _gc.append(cl); _gc.append(cl)
	else:
		_v.append(pa); _v.append(pb); _v.append(pc)
		_n.append(qa); _n.append(qb); _n.append(qc)
		_c.append(cl); _c.append(cl); _c.append(cl)


func _quad(t: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, cl: Color) -> void:
	_tri(t, a, b, c, na, nb, nc, cl)
	_tri(t, a, c, d, na, nc, nd, cl)


## 평면 삼각형. out: 바깥쪽을 가리키는 대략의 방향
func tri(a: Vector3, b: Vector3, c: Vector3, cl, out := Vector3.UP, t := Transform3D.IDENTITY, both := false) -> void:
	var nn := (b - a).cross(c - a).normalized()
	if nn.dot(out) < 0:
		nn = -nn
	_tri(t, a, b, c, nn, nn, nn, col(cl))
	if both:
		_tri(t, a, b, c, -nn, -nn, -nn, col(cl))


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cl, out := Vector3.UP, t := Transform3D.IDENTITY, both := false) -> void:
	tri(a, b, c, cl, out, t, both)
	tri(a, c, d, cl, out, t, both)


## ---------- 상자 (모서리 깎기 · 위쪽 좁히기) ----------
## top: 윗면의 x·z 배율 (1보다 작으면 위로 갈수록 좁아진다)
func box(size: Vector3, pos: Vector3, cl, rot := Vector3.ZERO, bevel := 0.0, top := Vector2.ONE) -> void:
	var t := xf(pos, rot)
	var c := col(cl)
	var h := size * 0.5
	var bv := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	## 면 a 위에서 모서리 sg 쪽에 가장 가까운 점
	var P := func(a: int, sg: Vector3) -> Vector3:
		var p := Vector3.ZERO
		for i in 3:
			p[i] = sg[i] * (h[i] if i == a else h[i] - bv)
		var k := (p.y / h.y) * 0.5 + 0.5
		p.x *= lerpf(1.0, top.x, k)
		p.z *= lerpf(1.0, top.y, k)
		return p
	## 면 법선 (좁히기를 반영해 실제 꼭짓점에서 계산)
	var fn := {}
	for a in 3:
		for s in [-1.0, 1.0]:
			var u := (a + 1) % 3
			var w := (a + 2) % 3
			var q: Array = []
			for k in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var sg := Vector3.ZERO
				sg[a] = s
				sg[u] = k[0]
				sg[w] = k[1]
				q.append(P.call(a, sg))
			var nn: Vector3 = (q[1] - q[0]).cross(q[2] - q[0]).normalized()
			var ax := Vector3.ZERO
			ax[a] = s
			if nn.dot(ax) < 0:
				nn = -nn
			fn[a * 2 + (1 if s > 0 else 0)] = nn
			_quad(t, q[0], q[1], q[2], q[3], nn, nn, nn, nn, c)
	if bv <= 0.0:
		return
	var N := func(a: int, s: float) -> Vector3: return fn[a * 2 + (1 if s > 0 else 0)]
	## 모서리 띠: 양쪽 면의 법선을 이어 둥글게 보이게 한다
	for e in 3:
		var u := (e + 1) % 3
		var w := (e + 2) % 3
		for s1 in [-1.0, 1.0]:
			for s2 in [-1.0, 1.0]:
				var s0 := Vector3.ZERO
				s0[u] = s1
				s0[w] = s2
				var sa := s0
				sa[e] = -1.0
				var sb := s0
				sb[e] = 1.0
				var nu: Vector3 = N.call(u, s1)
				var nw: Vector3 = N.call(w, s2)
				_quad(t, P.call(u, sa), P.call(u, sb), P.call(w, sb), P.call(w, sa), nu, nu, nw, nw, c)
	## 꼭짓점 삼각형
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var sg := Vector3(sx, sy, sz)
				_tri(t, P.call(0, sg), P.call(1, sg), P.call(2, sg), N.call(0, sx), N.call(1, sy), N.call(2, sz), c)


## ---------- 회전체 ----------
## prof: Vector2(반지름, 높이) 목록을 Y축 둘레로 돌린다. 꺾임이 완만한 곳은 매끈하게 잇는다
func lathe(prof: Array, pos: Vector3, cl, rot := Vector3.ZERO, seg := 12, cols: Array = []) -> void:
	var t := xf(pos, rot)
	var base_c := col(cl)
	var sn: Array = []
	for i in prof.size() - 1:
		var d: Vector2 = prof[i + 1] - prof[i]
		var nn := Vector2(d.y, -d.x)
		sn.append(nn.normalized() if nn.length() > 1e-6 else Vector2(0, -1 if i == 0 else 1))
	for i in prof.size() - 1:
		var n0: Vector2 = sn[i]
		var n1: Vector2 = sn[i]
		if i > 0 and sn[i - 1].dot(sn[i]) > 0.55:
			n0 = (sn[i - 1] + sn[i]).normalized()
		if i < sn.size() - 1 and sn[i + 1].dot(sn[i]) > 0.55:
			n1 = (sn[i + 1] + sn[i]).normalized()
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var c: Color = col(cols[i]) if i < cols.size() else base_c
		for j in seg:
			var a0 := j / float(seg) * TAU
			var a1 := (j + 1) / float(seg) * TAU
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var v00 := d0 * p0.x + Vector3(0, p0.y, 0)
			var v01 := d1 * p0.x + Vector3(0, p0.y, 0)
			var v10 := d0 * p1.x + Vector3(0, p1.y, 0)
			var v11 := d1 * p1.x + Vector3(0, p1.y, 0)
			var m00 := d0 * n0.x + Vector3(0, n0.y, 0)
			var m01 := d1 * n0.x + Vector3(0, n0.y, 0)
			var m10 := d0 * n1.x + Vector3(0, n1.y, 0)
			var m11 := d1 * n1.x + Vector3(0, n1.y, 0)
			if p0.x > 1e-5:
				_tri(t, v00, v01, v11, m00, m01, m11, c)
			if p1.x > 1e-5:
				_tri(t, v00, v11, v10, m00, m11, m10, c)


## 원기둥·원뿔대. axis: "y"(기본) / "x" / "z". r0이 축의 음수 쪽 끝 반지름
func cyl(r0: float, r1: float, hgt: float, pos: Vector3, cl, axis := "y", seg := 10, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot)
	if axis == "x":
		b = b * Basis.from_euler(Vector3(0, 0, -PI / 2))
	elif axis == "z":
		b = b * Basis.from_euler(Vector3(PI / 2, 0, 0))
	var keep := base
	base = base * Transform3D(b, pos)
	lathe([Vector2(0, -hgt / 2), Vector2(r0, -hgt / 2), Vector2(r1, hgt / 2), Vector2(0, hgt / 2)], Vector3.ZERO, cl, Vector3.ZERO, seg)
	base = keep


## a에서 b로 이어지는 막대 (팔다리·포신). r0은 a 쪽 반지름
func beam(a: Vector3, b: Vector3, r0: float, r1: float, cl, seg := 8, round_ends := false, rings := 1) -> void:
	var d := b - a
	var len := d.length()
	if len < 1e-5:
		return
	var y := d / len
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	var keep := base
	base = base * Transform3D(Basis(x, y, z), a)
	var mid: Array = []
	for i in range(0, rings + 1):
		var k := i / float(rings)
		mid.append(Vector2(lerpf(r0, r1, k), len * k))
	var prof: Array = [Vector2(0, 0)] + mid + [Vector2(0, len)]
	if round_ends:
		prof = [Vector2(0, -r0 * 0.7), Vector2(r0 * 0.75, -r0 * 0.45)] + mid + [Vector2(r1 * 0.75, len + r1 * 0.45), Vector2(0, len + r1 * 0.7)]
	lathe(prof, Vector3.ZERO, cl, Vector3.ZERO, seg)
	base = keep


## 타원체. y_from: 아래쪽을 잘라낼 높이 (-1 = 온전한 공, 0 = 반구)
func sphere(r: float, pos: Vector3, cl, scl := Vector3.ONE, seg := 12, rings := 8, y_from := -1.0, rot := Vector3.ZERO) -> void:
	var t := xf(pos, rot)
	var c := col(cl)
	var l0 := asin(clampf(y_from, -1.0, 1.0))
	var inv := Vector3(1.0 / scl.x, 1.0 / scl.y, 1.0 / scl.z)
	var U := func(l: float, a: float) -> Vector3: return Vector3(cos(a) * cos(l), sin(l), sin(a) * cos(l))
	for i in rings:
		var la := lerpf(l0, PI / 2, i / float(rings))
		var lb := lerpf(l0, PI / 2, (i + 1) / float(rings))
		for j in seg:
			var a0 := j / float(seg) * TAU
			var a1 := (j + 1) / float(seg) * TAU
			var u00: Vector3 = U.call(la, a0)
			var u01: Vector3 = U.call(la, a1)
			var u10: Vector3 = U.call(lb, a0)
			var u11: Vector3 = U.call(lb, a1)
			if cos(la) > 1e-4:
				_tri(t, u00 * scl * r, u01 * scl * r, u11 * scl * r, u00 * inv, u01 * inv, u11 * inv, c)
			if cos(lb) > 1e-4:
				_tri(t, u00 * scl * r, u11 * scl * r, u10 * scl * r, u00 * inv, u11 * inv, u10 * inv, c)


## 노이즈로 울퉁불퉁한 덩어리 (바위·나무 잎). 면마다 평평하게 칠해 로우폴리 느낌을 낸다.
## c_top/c_bot: 위·아래 색 (아래를 어둡게 주면 덩어리감이 산다)
func blob(r: float, pos: Vector3, c_top, c_bot, scl := Vector3.ONE, seed_v := 0.0, rough := 0.25, sub := 2, freq := 1.6) -> void:
	_nz()
	var ct := col(c_top)
	var cb := col(c_bot)
	var t := xf(pos)
	var tris: Array = []
	var o := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for f in [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 4, 2], [1, 3, 4], [1, 5, 3], [1, 2, 5]]:
		tris.append([o[f[0]], o[f[1]], o[f[2]]])
	for s in sub:
		var nt: Array = []
		for q in tris:
			var ab: Vector3 = (q[0] + q[1]).normalized()
			var bc: Vector3 = (q[1] + q[2]).normalized()
			var ca: Vector3 = (q[2] + q[0]).normalized()
			nt.append([q[0], ab, ca])
			nt.append([q[1], bc, ab])
			nt.append([q[2], ca, bc])
			nt.append([ab, bc, ca])
		tris = nt
	var D := func(u: Vector3) -> Vector3:
		var k := 1.0 + rough * _noise.get_noise_3d(u.x * freq + seed_v * 7.3, u.y * freq + seed_v * 3.1, u.z * freq - seed_v * 5.7)
		return u * scl * r * k
	var i := 0
	for q in tris:
		var a: Vector3 = D.call(q[0])
		var b: Vector3 = D.call(q[1])
		var c: Vector3 = D.call(q[2])
		var nn := (b - a).cross(c - a).normalized()
		var mid: Vector3 = (q[0] + q[1] + q[2]) / 3.0
		if nn.dot(mid * scl) < 0:
			nn = -nn
		## 위를 보는 면일수록 밝게 + 면마다 조금씩 다르게
		var k := clampf(nn.y * 0.6 + 0.5, 0.0, 1.0)
		var cc := cb.lerp(ct, k)
		var jit := 0.94 + 0.12 * fposmod(sin(i * 12.9898 + seed_v) * 43758.5453, 1.0)
		cc = Color(cc.r * jit, cc.g * jit, cc.b * jit)
		_tri(t, a, b, c, nn, nn, nn, cc)
		i += 1
