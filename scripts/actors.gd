extends RefCounted
## 병사·전차·드론·포탑·헬기 등 움직이는 모델. 모두 +X 방향을 바라보게 만든다.
## 게임 각도 a(평면 x→, y↓)를 쓰려면 rotation.y = -a 로 돌린다.

const ML := preload("res://scripts/meshlib.gd")
const MK := preload("res://scripts/modelkit.gd")

const LOOK := {
	pl = {body = "#6b6a4c", leg = "#5a5a40", vest = "#4a4b35", pouch = "#5e5f44", helm = "#7a7457", face = "#1a1b1c", acc = "#f2c21b", glove = "#222320", gun = 21, pack = "#4f513b", sf = true, k = 1.0},
	ru = {body = "#4a4038", leg = "#3a332c", vest = "#2e2924", helm = "#5c2420", face = "#1a1515", acc = "#c0392b", glove = "#2a2420", gun = 11, k = 0.95},
	sh = {body = "#2c2d31", leg = "#232427", vest = "#1c1d20", helm = "#4e1c1a", face = "#4a5058", acc = "#c0392b", glove = "#18191b", gun = 0, shield = true, k = 1.15},
	rf = {body = "#6e6248", leg = "#5a503b", vest = "#4a4130", helm = "#4c2a22", face = "#2a2018", acc = "#c0392b", glove = "#2a2420", gun = 23, pack = "#5a4e36", k = 1.02},
	## 아군 부대원. like: 머리·장구류를 빌려 올 기본 형태, gun_like: 총 모양
	al = {body = "#55603f", leg = "#49523a", vest = "#3a4230", helm = "#55603f", face = "#2a2018", acc = "#4fa3d9", glove = "#222320", gun = 21, pack = "#434b33", k = 0.97, like = "rf", gun_like = "pl"},
	## 특수부대 분대원: 플레이어와 같은 장비, 식별색만 파랑
	ae = {body = "#6b6a4c", leg = "#5a5a40", vest = "#4a4b35", pouch = "#5e5f44", helm = "#7a7457", face = "#1a1b1c", acc = "#4fa3d9", glove = "#222320", gun = 21, pack = "#4f513b", sf = true, k = 0.97, like = "pl"},
}

## 화면에서 읽히도록 병사를 실제 비율보다 키운다 (충돌 판정은 그대로)
const BIG := 1.18

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


static func _finish(root: Node3D, outlined := true) -> Node3D:
	if outlined:
		ML.outline(root)
	var arr: Array = []
	_collect(root, arr)
	root.set_meta("meshes", arr)
	return root


## ---------- 병사 (특수부대 / 적) ----------
## 실제 체형(키 1.8 m, 약 7.5등신)에 견착 자세. 허벅지·정강이를 따로 두어 무릎이 굽는다.
## 노드: Body > HipL/HipR(허벅지) > Knee(정강이·군화), Body > 몸통 메시, Body > Gun
const GEAR := "#23241f"
const METAL := "#17181a"
const POLY := "#2a2c2f"
const WOOD := "#6a4526"
const GUN_POS := Vector3(0.12, 1.36, 0.13)
const HIP_Y := 0.92
const THIGH := 0.45
## 위장 무늬 색 (전투복)
const CAMO := {
	pl = ["#6f6d50", "#585c40", "#8a8162", "#474534"],
	ru = ["#4b4239", "#39332c", "#5c4f41"],
	rf = ["#6e6349", "#594f3a", "#80735a", "#4a4232"],
	sh = ["#2d2e32", "#232427", "#34363b"],
	al = ["#55603f", "#49523a", "#66704c", "#3c4431"],
	ae = ["#6f6d50", "#585c40", "#8a8162", "#474534"],
}


static func soldier(type: String, _tint := "") -> Node3D:
	var o: Dictionary = LOOK[type]
	var root = Node3D.new()
	var b = Node3D.new()
	b.name = "Body"
	b.scale = Vector3.ONE * o.k * BIG
	root.add_child(b)
	for s in [-1, 1]:
		var hip = Node3D.new()
		hip.name = "HipL" if s < 0 else "HipR"
		hip.position = Vector3(0, HIP_Y, s * 0.1)
		b.add_child(hip)
		MK.inst(hip, MK.cached("thigh_%s_%d" % [type, s], func(): return _thigh(o, type, s)), Vector3.ZERO, true)
		var knee = Node3D.new()
		knee.name = "Knee"
		knee.position = Vector3(0.01, -THIGH, 0)
		hip.add_child(knee)
		MK.inst(knee, MK.cached("shin_" + type, func(): return _shin(o, type)), Vector3.ZERO, true)
	var g: float = o.gun * 0.038
	MK.inst(b, MK.cached("torso_" + type, func(): return _torso(o, type, g)), Vector3.ZERO, true)
	if g > 0:
		var gun = Node3D.new()
		gun.name = "Gun"
		gun.position = GUN_POS
		b.add_child(gun)
		MK.inst(gun, MK.cached("gun_" + type, func(): return _gun(str(o.get("gun_like", o.get("like", type))), g)), Vector3.ZERO, true)
	if o.get("sf", false):
		## 아군 식별등 (헬멧 뒤 적외선 스트로브 자리)
		ML.no_shadow(ML.box(b, Vector3(0.03, 0.035, 0.05), o.acc, Vector3(-0.135, 1.73, 0), Vector3.ZERO, ML.mat(o.acc, 2.0, 1.0, true)))
	walk(root, 0.0, 0.0)
	return _finish(root, false)


static func _thigh(o: Dictionary, type: String, s: int) -> Mesh:
	var b = MK.new()
	b.camo = CAMO[type]
	b.beam(Vector3(0, 0.05, 0), Vector3(0.01, -THIGH, 0), 0.1, 0.074, o.leg, 8, true, 3)
	b.camo = []
	## 건빵 주머니
	b.box(Vector3(0.12, 0.17, 0.045), Vector3(0.0, -0.22, s * 0.086), Color(str(o.leg)).darkened(0.12), Vector3.ZERO, 0.018)
	if o.get("sf", false) and s > 0:
		## 권총집 + 허벅지 끈
		b.box(Vector3(0.075, 0.2, 0.055), Vector3(0.02, -0.17, 0.125), GEAR, Vector3(0, 0, 0.1), 0.015)
		b.box(Vector3(0.03, 0.07, 0.03), Vector3(0.035, -0.05, 0.13), METAL)
		b.box(Vector3(0.2, 0.025, 0.2), Vector3(0.01, -0.2, 0), GEAR)
	return b.commit()


static func _shin(o: Dictionary, type: String) -> Mesh:
	var b = MK.new()
	var boot = "#5a4a36" if o.get("sf", false) else "#221f1b"
	b.camo = CAMO[type]
	b.beam(Vector3(0, 0.03, 0), Vector3(-0.012, -0.2, 0), 0.074, 0.07, o.leg, 8, true, 2)
	b.beam(Vector3(-0.012, -0.2, 0), Vector3(0, -0.37, 0), 0.07, 0.052, o.leg, 8, false, 2)
	b.camo = []
	if o.get("sf", false) or o.get("shield", false):
		b.box(Vector3(0.06, 0.13, 0.125), Vector3(0.06, 0.0, 0), GEAR, Vector3(0, 0, 0.1), 0.03)
	## 전투화: 목 + 발등(앞코가 낮다) + 밑창
	b.box(Vector3(0.125, 0.17, 0.115), Vector3(0, -0.355, 0), boot, Vector3.ZERO, 0.035)
	b.box(Vector3(0.265, 0.085, 0.112), Vector3(0.068, -0.412, 0), boot, Vector3.ZERO, 0.035, Vector2(0.86, 0.9))
	b.box(Vector3(0.27, 0.026, 0.116), Vector3(0.068, -0.457, 0), "#0d0d0c")
	return b.commit()


static func _torso(o: Dictionary, type: String, g: float) -> Mesh:
	var b = MK.new()
	var sf: bool = o.get("sf", false)
	var heavy: bool = o.get("shield", false)
	var body = o.body
	var vest = o.vest
	var pouch = o.get("pouch", Color(str(o.vest)).lightened(0.12))
	var pal: Array = CAMO[type]
	## 상체는 골반을 축으로 앞으로 조금 숙인다 (전투 자세)
	var lean := Transform3D(Basis.from_euler(Vector3(0, 0, -0.1)), Vector3(0, HIP_Y, 0)) * Transform3D(Basis(), Vector3(0, -HIP_Y, 0))
	b.base = lean
	## 골반·배·가슴 (타원체로 몸의 곡면을 만든다)
	b.camo = pal
	b.sphere(0.2, Vector3(0, 0.96, 0), o.leg, Vector3(0.62, 0.6, 0.86), 10, 6)
	b.sphere(0.2, Vector3(0, 1.14, 0), body, Vector3(0.6, 0.85, 0.82), 10, 6)
	b.sphere(0.2, Vector3(0.005, 1.33, 0), body, Vector3(0.68, 0.95, 0.98), 10, 6)
	b.camo = []
	b.box(Vector3(0.26, 0.055, 0.36), Vector3(0, 1.02, 0), GEAR, Vector3.ZERO, 0.02)
	## 플레이트 캐리어: 앞판·뒷판·옆 띠·어깨끈
	b.box(Vector3(0.07, 0.32, 0.3), Vector3(0.118, 1.31, 0), vest, Vector3.ZERO, 0.03)
	b.box(Vector3(0.07, 0.34, 0.3), Vector3(-0.118, 1.31, 0), vest, Vector3.ZERO, 0.03)
	b.box(Vector3(0.27, 0.13, 0.375), Vector3(0, 1.165, 0), vest, Vector3.ZERO, 0.04)
	for z in [-0.1, 0.1]:
		b.box(Vector3(0.25, 0.03, 0.06), Vector3(0, 1.487, z), vest, Vector3.ZERO, 0.012)
	if heavy:
		## 중장갑: 가슴 덧판 + 목 보호대 + 사타구니 보호대
		b.box(Vector3(0.06, 0.26, 0.26), Vector3(0.17, 1.32, 0), "#3a3d44", Vector3.ZERO, 0.03)
		b.box(Vector3(0.13, 0.1, 0.24), Vector3(0.0, 1.535, 0), vest, Vector3.ZERO, 0.035)
		b.box(Vector3(0.05, 0.16, 0.2), Vector3(0.12, 0.93, 0), vest, Vector3.ZERO, 0.03)
	else:
		## 탄입대 3개 (탄창 머리가 보인다)
		for z in [-0.085, 0.0, 0.085]:
			b.box(Vector3(0.055, 0.15, 0.075), Vector3(0.175, 1.2, z), pouch, Vector3.ZERO, 0.015)
			b.box(Vector3(0.03, 0.03, 0.05), Vector3(0.175, 1.29, z), "#2a2b28")
		b.box(Vector3(0.05, 0.09, 0.14), Vector3(0.17, 1.37, 0), pouch, Vector3.ZERO, 0.015)
	## 허리 뒤 구급낭·수통
	b.box(Vector3(0.08, 0.1, 0.14), Vector3(-0.14, 1.03, 0.08), pouch, Vector3.ZERO, 0.025)
	b.cyl(0.045, 0.045, 0.14, Vector3(-0.12, 1.04, -0.13), pouch, "y", 8)
	if sf:
		## 무전기 + 안테나
		b.box(Vector3(0.06, 0.14, 0.07), Vector3(-0.02, 1.2, -0.215), GEAR, Vector3.ZERO, 0.015)
		b.beam(Vector3(-0.03, 1.27, -0.215), Vector3(-0.06, 1.75, -0.23), 0.007, 0.004, GEAR, 4)
	if o.has("pack"):
		var pk = Color(str(o.pack))
		b.box(Vector3(0.16, 0.4, 0.3), Vector3(-0.235, 1.3, 0), pk, Vector3.ZERO, 0.06)
		b.box(Vector3(0.07, 0.16, 0.2), Vector3(-0.33, 1.24, 0), pk.darkened(0.12), Vector3.ZERO, 0.03)
		b.box(Vector3(0.15, 0.03, 0.31), Vector3(-0.235, 1.4, 0), GEAR)
	## 목·머리
	var skin = "#33302a" if sf else "#a8835f"
	b.cyl(0.054, 0.05, 0.11, Vector3(0.012, 1.54, 0), skin)
	b.sphere(0.105, Vector3(0.027, 1.655, 0), skin, Vector3(0.95, 1.1, 0.85), 10, 7)
	var hc: Array = pal
	match str(o.get("like", type)):
		"pl":
			## 하이컷 헬멧(위장 커버) + 헤드셋 + 보안경 + 올려 둔 쌍안 야간투시경
			b.camo = hc
			b.sphere(0.127, Vector3(0.02, 1.69, 0), o.helm, Vector3(1.02, 0.86, 0.95), 12, 6, -0.12)
			b.camo = []
			for z in [-0.108, 0.108]:
				b.cyl(0.046, 0.046, 0.05, Vector3(0.012, 1.652, z), GEAR, "z", 8)
				b.box(Vector3(0.12, 0.022, 0.016), Vector3(0.015, 1.715, z * 1.12), GEAR)
			b.beam(Vector3(0.03, 1.615, 0.11), Vector3(0.11, 1.6, 0.05), 0.008, 0.008, GEAR, 4)
			b.box(Vector3(0.03, 0.042, 0.16), Vector3(0.12, 1.668, 0), "#1c2226", Vector3.ZERO, 0.012)
			b.box(Vector3(0.045, 0.045, 0.06), Vector3(0.135, 1.762, 0), GEAR, Vector3.ZERO, 0.01)
			for z in [-0.034, 0.034]:
				b.beam(Vector3(0.14, 1.775, z), Vector3(0.185, 1.865, z), 0.026, 0.03, GEAR, 8)
			b.box(Vector3(0.04, 0.06, 0.09), Vector3(-0.115, 1.7, 0), GEAR, Vector3.ZERO, 0.012)
		"ru":
			## 적갈색 베레모 + 수염·목도리
			b.sphere(0.118, Vector3(0.012, 1.745, 0.018), o.helm, Vector3(1.05, 0.42, 1.15), 12, 6)
			b.cyl(0.103, 0.103, 0.03, Vector3(0.02, 1.722, 0), Color(str(o.helm)).darkened(0.4), "y", 12)
			b.sphere(0.09, Vector3(0.05, 1.6, 0), "#3b352e", Vector3(0.9, 0.7, 1.0), 8, 5)
			b.box(Vector3(0.02, 0.022, 0.12), Vector3(0.118, 1.675, 0), "#1a1515")
		"rf":
			## 위장 커버 철모 + 식별 띠 + 헬멧 위 고글
			b.camo = hc
			b.sphere(0.134, Vector3(0.02, 1.685, 0), o.body, Vector3(1.04, 0.88, 1.0), 12, 6, -0.1)
			b.camo = []
			b.lathe([Vector2(0.136, 0.0), Vector2(0.139, 0.03)], Vector3(0.02, 1.7, 0), o.acc, Vector3.ZERO, 12)
			b.box(Vector3(0.035, 0.04, 0.15), Vector3(0.13, 1.745, 0), "#20262a", Vector3.ZERO, 0.012)
			b.sphere(0.085, Vector3(0.055, 1.6, 0), "#4a4336", Vector3(0.85, 0.6, 1.0), 8, 5)
			b.box(Vector3(0.02, 0.022, 0.12), Vector3(0.12, 1.672, 0), "#1a1515")
		"sh":
			## 풀페이스 방탄 헬멧 + 바이저
			b.sphere(0.145, Vector3(0.02, 1.672, 0), "#26272b", Vector3(1.03, 0.98, 1.0), 12, 7, -0.5)
			b.box(Vector3(0.035, 0.1, 0.2), Vector3(0.14, 1.655, 0), "#7f9fb0", Vector3.ZERO, 0.025)
			b.lathe([Vector2(0.147, 0.0), Vector2(0.15, 0.03)], Vector3(0.02, 1.735, 0), o.acc, Vector3.ZERO, 12)
	## 어깨·팔 (팔은 총을 잡는 손 위치에 맞춘다)
	b.base = Transform3D.IDENTITY
	var hands: Array = []
	if g > 0:
		hands = [[Vector3(0.2, 1.24, -0.17), GUN_POS + Vector3(minf(0.36, g * 0.45), -0.035, -0.01)], [Vector3(-0.03, 1.2, 0.29), GUN_POS + Vector3(0.0, -0.085, 0.0)]]
	else:
		hands = [[Vector3(0.2, 1.24, -0.26), Vector3(0.42, 1.2, -0.18)], [Vector3(0.2, 1.24, 0.26), Vector3(0.42, 1.2, 0.18)]]
	for i in 2:
		var sg = -1.0 if i == 0 else 1.0
		var sh: Vector3 = lean * Vector3(0, 1.47, sg * 0.2)
		b.camo = pal
		b.sphere(0.088, sh, body, Vector3.ONE, 10, 6)
		b.beam(sh, hands[i][0], 0.062, 0.052, body, 8, true, 3)
		b.beam(hands[i][0], hands[i][1], 0.052, 0.04, body, 8, true, 3)
		b.camo = []
		b.box(Vector3(0.09, 0.058, 0.078), hands[i][1], o.glove, Vector3.ZERO, 0.024)
		if sf or heavy:
			b.box(Vector3(0.08, 0.075, 0.08), hands[i][0], GEAR, Vector3.ZERO, 0.025)
		if heavy:
			b.box(Vector3(0.15, 0.07, 0.15), sh + Vector3(0, 0.075, sg * 0.02), "#3a3d44", Vector3(sg * 0.3, 0, 0), 0.025)
		## 어깨 표식
		b.box(Vector3(0.07, 0.07, 0.012), sh + Vector3(0.0, -0.06, sg * 0.068), o.acc)
	if heavy:
		## 방패: 본체 + 관측창 + 식별 띠
		b.box(Vector3(0.05, 1.2, 0.76), Vector3(0.5, 0.92, 0), "#3f4650", Vector3.ZERO, 0.045, Vector2(1.0, 0.9))
		b.box(Vector3(0.02, 0.14, 0.38), Vector3(0.53, 1.3, 0), "#9fc4d6", Vector3.ZERO, 0.015)
		b.box(Vector3(0.015, 0.06, 0.6), Vector3(0.53, 0.82, 0), o.acc)
		b.box(Vector3(0.07, 0.06, 0.78), Vector3(0.5, 0.35, 0), "#25292f", Vector3.ZERO, 0.02)
	return b.commit()


## 총기. 원점이 손잡이 위(총몸 가운데), 총열이 +X
static func _gun(type: String, g: float) -> Mesh:
	var b = MK.new()
	match type:
		"pl":
			## 소음기 카빈: 위·아래 총몸, 레일 총열덮개, 접철식 개머리판, 도트 사이트
			b.box(Vector3(0.21, 0.055, 0.05), Vector3(0.06, 0.02, 0), METAL, Vector3.ZERO, 0.01)
			b.box(Vector3(0.17, 0.05, 0.045), Vector3(0.04, -0.03, 0), METAL, Vector3.ZERO, 0.01)
			b.box(Vector3(0.25, 0.058, 0.055), Vector3(0.29, 0.018, 0), "#35372f", Vector3.ZERO, 0.012)
			b.box(Vector3(0.44, 0.014, 0.03), Vector3(0.19, 0.054, 0), "#101112")
			b.beam(Vector3(0.4, 0.018, 0), Vector3(g - 0.12, 0.018, 0), 0.012, 0.012, METAL, 6)
			b.cyl(0.024, 0.024, 0.19, Vector3(g - 0.03, 0.018, 0), "#0e0f10", "x", 8)
			b.box(Vector3(0.05, 0.19, 0.03), Vector3(0.105, -0.14, 0), "#2f3129", Vector3(0, 0, 0.2), 0.008)
			b.box(Vector3(0.04, 0.1, 0.035), Vector3(-0.01, -0.095, 0), POLY, Vector3(0, 0, -0.32), 0.01)
			b.cyl(0.016, 0.016, 0.19, Vector3(-0.13, 0.012, 0), METAL, "x", 6)
			b.box(Vector3(0.13, 0.085, 0.04), Vector3(-0.2, -0.012, 0), POLY, Vector3.ZERO, 0.012, Vector2(0.8, 1.0))
			b.box(Vector3(0.07, 0.05, 0.04), Vector3(0.07, 0.092, 0), METAL, Vector3.ZERO, 0.01)
			b.box(Vector3(0.008, 0.032, 0.028), Vector3(0.107, 0.095, 0), "#6fb0d8")
			b.box(Vector3(0.03, 0.09, 0.03), Vector3(0.3, -0.06, 0), POLY, Vector3.ZERO, 0.008)
			b.box(Vector3(0.07, 0.03, 0.03), Vector3(0.36, 0.018, 0.04), "#6f6a52")
		"rf":
			## 조준경 달린 반자동 저격총: 목제 개머리판·총열덮개, 긴 총열
			b.box(Vector3(0.24, 0.06, 0.045), Vector3(0.06, 0.0, 0), METAL, Vector3.ZERO, 0.01)
			b.box(Vector3(0.26, 0.05, 0.05), Vector3(0.31, 0.0, 0), WOOD, Vector3.ZERO, 0.014)
			b.beam(Vector3(0.44, 0.008, 0), Vector3(g, 0.008, 0), 0.012, 0.01, METAL, 6)
			b.cyl(0.018, 0.016, 0.08, Vector3(g - 0.02, 0.008, 0), METAL, "x", 6)
			b.box(Vector3(0.02, 0.05, 0.02), Vector3(g - 0.1, 0.035, 0), METAL)
			b.box(Vector3(0.3, 0.1, 0.04), Vector3(-0.2, -0.035, 0), WOOD, Vector3(0, 0, 0.16), 0.016, Vector2(0.7, 1.0))
			b.box(Vector3(0.045, 0.11, 0.03), Vector3(0.09, -0.085, 0), METAL, Vector3(0, 0, 0.08), 0.008)
			b.box(Vector3(0.04, 0.09, 0.035), Vector3(-0.02, -0.08, 0), WOOD, Vector3(0, 0, -0.3), 0.01)
			b.cyl(0.02, 0.02, 0.24, Vector3(0.07, 0.075, 0), METAL, "x", 8)
			b.cyl(0.027, 0.02, 0.05, Vector3(0.2, 0.075, 0), METAL, "x", 8)
			b.box(Vector3(0.02, 0.035, 0.02), Vector3(0.02, 0.048, 0), METAL)
			b.box(Vector3(0.02, 0.035, 0.02), Vector3(0.13, 0.048, 0), METAL)
		_:
			## 단축형 돌격소총: 목제 총열덮개, 휜 탄창, 접은 개머리판
			b.box(Vector3(0.22, 0.06, 0.045), Vector3(0.05, 0.0, 0), METAL, Vector3.ZERO, 0.01)
			b.box(Vector3(0.14, 0.05, 0.05), Vector3(0.22, 0.0, 0), WOOD, Vector3.ZERO, 0.014)
			b.beam(Vector3(0.28, 0.006, 0), Vector3(g + 0.04, 0.006, 0), 0.012, 0.011, METAL, 6)
			b.cyl(0.02, 0.016, 0.06, Vector3(g + 0.03, 0.006, 0), METAL, "x", 6)
			b.box(Vector3(0.02, 0.05, 0.02), Vector3(g - 0.04, 0.034, 0), METAL)
			b.box(Vector3(0.05, 0.11, 0.028), Vector3(0.1, -0.08, 0), "#3a2c1c", Vector3(0, 0, 0.2), 0.008)
			b.box(Vector3(0.048, 0.1, 0.028), Vector3(0.135, -0.165, 0), "#3a2c1c", Vector3(0, 0, 0.5), 0.008)
			b.box(Vector3(0.04, 0.09, 0.035), Vector3(-0.03, -0.08, 0), WOOD, Vector3(0, 0, -0.3), 0.01)
			b.box(Vector3(0.2, 0.02, 0.02), Vector3(-0.02, 0.0, 0.035), METAL)
	return b.commit()


## 걷기: 허벅지를 앞뒤로 흔들고, 발을 앞으로 옮기는 동안 무릎을 굽힌다. 서 있을 때는 한 발을 앞에 둔 자세
static func walk(root: Node3D, t: float, amt: float) -> void:
	var b = root.get_node_or_null("Body")
	if b == null:
		return
	var hl: Node3D = b.get_node("HipL")
	var hr: Node3D = b.get_node("HipR")
	var idle = 1.0 - amt
	var s = sin(t)
	var c = cos(t)
	hl.rotation.z = s * 0.6 * amt + 0.2 * idle
	hr.rotation.z = -s * 0.6 * amt - 0.14 * idle
	hl.get_node("Knee").rotation.z = -(0.12 + 0.95 * maxf(0.0, c)) * amt - 0.22 * idle
	hr.get_node("Knee").rotation.z = -(0.12 + 0.95 * maxf(0.0, -c)) * amt - 0.1 * idle
	b.position.y = (absf(c) * 0.045 - 0.02) * amt - 0.012 * idle


## ---------- 주력 전차 ----------
## ally: 아군 지원 전차 (짙은 녹색 + 파란 식별 띠)
static func tank(ally := false) -> Node3D:
	var root = Node3D.new()
	var hull = Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	MK.inst(hull, MK.cached("tank_hull_a" if ally else "tank_hull", func(): return _tank_hull(ally)), Vector3.ZERO, true)
	var tur = Node3D.new()
	tur.name = "Turret"
	tur.position = Vector3(0, 1.1, 0)
	root.add_child(tur)
	MK.inst(tur, MK.cached("tank_turret_a" if ally else "tank_turret", func(): return _tank_turret(ally)), Vector3.ZERO, true)
	return _finish(root, false)


## ---------- 길리 저격수: 엎드린 몸을 땅 색 덤불 덩어리가 덮고 있다. 외곽선도 그림자도 없다 ----------
## g: 바이옴 지면 색 넷. Glint(조준경 반짝임)는 조준하거나 들켰을 때만 켠다
static func sniper(g: Array) -> Node3D:
	var root = Node3D.new()
	var b = Node3D.new()
	b.name = "Body"
	root.add_child(b)
	MK.inst(b, MK.cached("sniper_" + str(g[0]), func():
		var k = MK.new()
		var c0 = Color(str(g[0]))
		var c1 = Color(str(g[1]))
		var c2 = Color(str(g[2]))
		## 몸통·다리·머리 자리에 덤불 덩어리 (윗면은 땅 색, 아랫면만 조금 어둡다)
		k.blob(0.42, Vector3(-0.1, 0.16, 0), c1, c2.darkened(0.12), Vector3(1.6, 0.5, 1.0), 2.0, 0.45, 2, 2.2)
		k.blob(0.3, Vector3(-0.85, 0.12, 0.14), c0, c2.darkened(0.12), Vector3(1.7, 0.45, 0.8), 5.0, 0.45, 1, 2.2)
		k.blob(0.3, Vector3(-0.8, 0.12, -0.18), c1, c2.darkened(0.12), Vector3(1.6, 0.45, 0.8), 7.0, 0.45, 1, 2.2)
		k.blob(0.24, Vector3(0.55, 0.2, 0.02), c0, c2.darkened(0.1), Vector3(1.1, 0.75, 1.0), 9.0, 0.5, 1, 2.4)
		## 총열만 살짝 나와 있다
		k.beam(Vector3(0.6, 0.17, 0.08), Vector3(1.45, 0.15, 0.08), 0.022, 0.018, c2.darkened(0.35), 5)
		for i in 5:
			var a = i * 1.3
			k.beam(Vector3(cos(a) * 0.4 - 0.1, 0.25, sin(a) * 0.3), Vector3(cos(a) * 0.62 - 0.1, 0.42, sin(a) * 0.46), 0.012, 0.004, c1.darkened(0.1), 3)
		return k.commit()))
	var gl = ML.no_shadow(ML.sph(b, 0.07, "#ffffff", Vector3(0.72, 0.3, 0.08), Vector3.ONE, ML.mat("#fff2c8", 6.0, 1.0, true), 6))
	gl.name = "Glint"
	gl.visible = false
	_no_shadow_all(root)
	return _finish(root, false)


## ---------- 보스 (기수 +X). Hull / Turret 구조는 전차와 같다 ----------
static func boss(kind: String) -> Node3D:
	var root = Node3D.new()
	var hull = Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	var tur = Node3D.new()
	tur.name = "Turret"
	root.add_child(tur)
	match kind:
		"b1":
			_b1(hull, tur)
		"b2":
			_b2(hull, tur)
		_:
			_b3(hull, tur)
	return _finish(root, false)


## 굵은 포신 (회전체). 원점에서 +X로 len만큼
static func _barrel(b, at: Vector3, len: float, r: float, elev := 0.0) -> void:
	var keep = b.base
	b.base = keep * Transform3D(Basis.from_euler(Vector3(0, 0, -PI / 2 + elev)), at)
	b.lathe([Vector2(0.0, 0.0), Vector2(r * 1.5, 0.0), Vector2(r * 1.25, len * 0.12), Vector2(r, len * 0.16), Vector2(r * 1.4, len * 0.42), Vector2(r * 1.4, len * 0.52), Vector2(r * 0.92, len * 0.55), Vector2(r * 0.85, len * 0.9), Vector2(r * 1.35, len * 0.91), Vector2(r * 1.35, len), Vector2(r * 0.7, len), Vector2(0.0, len * 0.98)],
		Vector3.ZERO, "#33372d", Vector3.ZERO, 12, ["#33372d", "#3d4236", "#3d4236", "#2c2f27", "#2c2f27", "#2c2f27", "#33372d", "#33372d", "#1c1e19", "#0e0e0d", "#0e0e0d"])
	b.base = keep


## 궤도 한 줄 (x 길이 len, 바퀴 n개)
static func _track(b, len: float, z: float, n: int, wr := 0.3, h := 0.7) -> void:
	b.box(Vector3(len, h, 0.7), Vector3(0, h * 0.52, z), "#1a1b18", Vector3.ZERO, 0.24)
	for i in n:
		var wx = -len / 2 + 0.5 + i * (len - 1.0) / maxf(1.0, n - 1)
		b.cyl(wr, wr, 0.74, Vector3(wx, wr + 0.04, z), "#2b2d27", "z", 10)
		b.cyl(wr * 0.45, wr * 0.45, 0.78, Vector3(wx, wr + 0.04, z), "#5a604e", "z", 8)


## 기관포 포탑 (작은 상자 + 쌍열 포신)
static func _autoturret(b, at: Vector3, col: String) -> void:
	b.cyl(0.42, 0.46, 0.14, at + Vector3(0, 0.07, 0), "#2b2e28", "y", 10)
	b.box(Vector3(0.9, 0.42, 0.8), at + Vector3(0, 0.34, 0), col, Vector3.ZERO, 0.08, Vector2(0.8, 0.8))
	for z in [-0.14, 0.14]:
		b.beam(at + Vector3(0.4, 0.34, z), at + Vector3(1.5, 0.36, z), 0.04, 0.035, "#141513", 6)
		b.cyl(0.055, 0.055, 0.14, at + Vector3(1.48, 0.36, z), "#0e0e0d", "x", 6)


## 다포탑 중전차: 폭이 넓은 차체, 앞쪽 양옆의 부포탑 둘, 큰 주포탑
static func _b1(hull: Node3D, tur: Node3D) -> void:
	MK.inst(hull, MK.cached("b1_hull", func():
		var b = MK.new()
		var c1 = "#5a5f4c"
		var c2 = "#454a3b"
		for s in [-1.0, 1.0]:
			_track(b, 6.6, s * 1.75, 9, 0.32, 0.8)
			b.box(Vector3(6.7, 0.07, 0.86), Vector3(0, 0.86, s * 1.75), c2, Vector3.ZERO, 0.02)
			for i in 6:
				b.box(Vector3(1.02, 0.42, 0.07), Vector3(-2.7 + i * 1.08, 0.6, s * 2.14), c1 if i % 2 == 0 else c2, Vector3.ZERO, 0.02)
		b.box(Vector3(6.0, 0.6, 2.9), Vector3(0, 0.75, 0), c2)
		b.box(Vector3(5.9, 0.8, 3.7), Vector3(-0.1, 1.3, 0), c1, Vector3.ZERO, 0.14, Vector2(0.92, 0.9))
		b.box(Vector3(1.4, 0.14, 3.4), Vector3(2.75, 1.25, 0), "#6b7260", Vector3(0, 0, -0.46), 0.04)
		b.box(Vector3(0.8, 0.5, 2.9), Vector3(3.1, 0.75, 0), c2, Vector3(0, 0, 0.5), 0.06)
		for i in 5:
			b.box(Vector3(0.14, 0.04, 2.2), Vector3(-1.6 - i * 0.26, 1.72, 0), "#2b2e26")
		b.box(Vector3(1.6, 0.05, 2.5), Vector3(-2.1, 1.7, 0), "#363a30")
		for s in [-1.0, 1.0]:
			b.cyl(0.24, 0.24, 1.1, Vector3(-3.25, 1.5, s * 1.0), c2, "z", 10)
			b.cyl(0.09, 0.09, 0.5, Vector3(-3.1, 1.15, s * 1.5), "#1e1f1c", "x", 8)
			b.box(Vector3(0.14, 0.14, 0.2), Vector3(3.0, 1.2, s * 1.4), "#e8e2c0")
		b.box(Vector3(0.24, 0.06, 3.6), Vector3(-0.9, 1.71, 0), "#a8322a")
		return b.commit()), Vector3.ZERO, true)
	for s in [-1, 1]:
		var sub = Node3D.new()
		sub.name = "SubL" if s < 0 else "SubR"
		hull.add_child(sub)
		MK.inst(sub, MK.cached("b1_sub", func():
			var b = MK.new()
			_autoturret(b, Vector3.ZERO, "#6b7260")
			return b.commit()), Vector3(1.75, 1.7, s * 1.25), true)
	tur.position = Vector3(0, 1.75, 0)
	MK.inst(tur, MK.cached("b1_turret", func():
		var b = MK.new()
		var c1 = "#656b58"
		b.cyl(1.3, 1.4, 0.2, Vector3(-0.5, 0.1, 0), "#2b2e28", "y", 14)
		b.box(Vector3(3.2, 0.9, 2.6), Vector3(-0.6, 0.62, 0), c1, Vector3.ZERO, 0.16, Vector2(0.82, 0.8))
		for s in [-1.0, 1.0]:
			b.box(Vector3(1.2, 0.7, 0.8), Vector3(0.7, 0.55, s * 0.8), "#757c68", Vector3(0, s * -0.42, 0), 0.08)
			for i in 4:
				b.box(Vector3(0.36, 0.06, 0.36), Vector3(-0.2 - i * 0.44, 1.1, s * 0.5), "#757c68", Vector3.ZERO, 0.02)
			for i in 3:
				b.cyl(0.06, 0.06, 0.26, Vector3(-0.2 - i * 0.2, 0.9, s * 1.32), "#454a3b", "x", 6, Vector3(0, s * -0.5, 0.5))
		b.box(Vector3(0.7, 0.66, 0.9), Vector3(1.15, 0.6, 0), "#454a3b", Vector3.ZERO, 0.08)
		_barrel(b, Vector3(1.4, 0.62, 0), 4.3, 0.15)
		b.cyl(0.4, 0.37, 0.24, Vector3(-1.0, 1.17, -0.6), "#454a3b", "y", 10)
		b.cyl(0.3, 0.3, 0.05, Vector3(-1.0, 1.31, -0.6), "#757c68", "y", 10)
		b.box(Vector3(0.5, 0.14, 0.12), Vector3(-0.7, 1.45, -0.6), "#1c1e1a", Vector3.ZERO, 0.02)
		b.beam(Vector3(-0.5, 1.45, -0.6), Vector3(0.4, 1.45, -0.6), 0.03, 0.025, "#0e0e0d", 5)
		b.box(Vector3(0.9, 0.5, 2.2), Vector3(-2.4, 0.5, 0), "#454a3b", Vector3.ZERO, 0.08)
		b.beam(Vector3(-2.0, 1.0, 0.9), Vector3(-2.2, 3.4, 0.95), 0.016, 0.008, "#1c1e1a", 4)
		return b.commit()), Vector3.ZERO, true)


## 열차포: 긴 선로 위의 포차. 받침대 위에 치켜든 초대형 포신
static func _b2(hull: Node3D, tur: Node3D) -> void:
	MK.inst(hull, MK.cached("b2_rails", func():
		var b = MK.new()
		## 선로 (양쪽으로 길게) + 침목 + 자갈 바닥
		b.box(Vector3(72, 0.1, 2.6), Vector3(0, 0.05, 0), "#4a463e")
		for z in [-0.75, 0.75]:
			b.box(Vector3(72, 0.14, 0.12), Vector3(0, 0.24, z), "#6e7276")
		for i in 60:
			b.box(Vector3(0.28, 0.1, 2.1), Vector3(-35.4 + i * 1.2, 0.14, 0), "#3a2c20")
		return b.commit()))
	MK.inst(hull, MK.cached("b2_car", func():
		var b = MK.new()
		var c1 = "#575d4b"
		var c2 = "#40453a"
		## 포차 대차 넷 + 차대
		for bx in [-4.2, -1.6, 1.6, 4.2]:
			b.box(Vector3(1.9, 0.4, 1.9), Vector3(bx, 0.7, 0), "#22241f", Vector3.ZERO, 0.06)
			for wx in [-0.55, 0.55]:
				for z in [-0.75, 0.75]:
					b.cyl(0.4, 0.4, 0.16, Vector3(bx + wx, 0.66, z), "#15161a", "z", 12)
		b.box(Vector3(11.6, 0.5, 2.8), Vector3(0, 1.2, 0), c2, Vector3.ZERO, 0.08)
		b.box(Vector3(11.8, 0.12, 3.0), Vector3(0, 1.5, 0), c1)
		## 장갑 측판 + 받침 지주
		for s in [-1.0, 1.0]:
			b.box(Vector3(6.4, 1.3, 0.14), Vector3(-0.4, 2.15, s * 1.42), c1, Vector3.ZERO, 0.04)
			for i in 5:
				b.box(Vector3(0.16, 1.34, 0.18), Vector3(-3.2 + i * 1.4, 2.15, s * 1.44), c2)
			b.beam(Vector3(2.0, 1.5, s * 1.2), Vector3(3.6, 0.1, s * 3.0), 0.1, 0.08, "#2b2e28", 6)
			b.beam(Vector3(-2.6, 1.5, s * 1.2), Vector3(-4.2, 0.1, s * 3.0), 0.1, 0.08, "#2b2e28", 6)
			b.cyl(0.4, 0.46, 0.1, Vector3(3.6, 0.06, s * 3.0), "#2b2e28", "y", 10)
			b.cyl(0.4, 0.46, 0.1, Vector3(-4.2, 0.06, s * 3.0), "#2b2e28", "y", 10)
		## 발전기실 + 탄약 승강기 + 기중기
		b.box(Vector3(2.4, 1.6, 2.4), Vector3(-4.4, 2.35, 0), c1, Vector3.ZERO, 0.1)
		b.box(Vector3(2.0, 0.1, 2.0), Vector3(-4.4, 3.2, 0), c2)
		b.cyl(0.16, 0.16, 0.9, Vector3(-5.0, 3.6, 0.7), "#1e1f1c", "y", 8)
		b.beam(Vector3(-3.0, 1.6, -0.9), Vector3(-3.0, 4.4, -0.9), 0.09, 0.07, "#c8a030", 6)
		b.beam(Vector3(-3.0, 4.4, -0.9), Vector3(-0.8, 4.1, -0.9), 0.07, 0.05, "#c8a030", 6)
		b.box(Vector3(1.0, 0.7, 1.2), Vector3(4.6, 1.95, 0), c2, Vector3.ZERO, 0.06)
		b.box(Vector3(0.24, 0.06, 2.86), Vector3(3.2, 1.57, 0), "#a8322a")
		b.glow = true
		b.box(Vector3(0.04, 0.2, 0.7), Vector3(-5.62, 2.5, 0), "#ffd596")
		b.glow = false
		return b.commit()), Vector3.ZERO, true)
	tur.position = Vector3(0, 1.7, 0)
	MK.inst(tur, MK.cached("b2_gun", func():
		var b = MK.new()
		## 포가 + 포미 + 치켜든 초대형 포신 + 주퇴기
		b.cyl(1.2, 1.3, 0.3, Vector3(0, 0.15, 0), "#2b2e28", "y", 14)
		for s in [-1.0, 1.0]:
			b.box(Vector3(2.6, 1.9, 0.26), Vector3(0.1, 1.2, s * 0.85), "#575d4b", Vector3.ZERO, 0.08, Vector2(0.6, 1.0))
			b.cyl(0.3, 0.3, 0.3, Vector3(0.1, 1.9, s * 0.95), "#33372d", "z", 10)
		var keep = b.base
		b.base = Transform3D(Basis.from_euler(Vector3(0, 0, 0.5)), Vector3(0.1, 1.9, 0))
		b.box(Vector3(2.2, 1.1, 1.2), Vector3(-0.9, 0, 0), "#40453a", Vector3.ZERO, 0.12)
		for z in [-0.42, 0.42]:
			b.cyl(0.16, 0.16, 2.6, Vector3(1.2, 0.5, z), "#6b7260", "x", 8)
		_barrel(b, Vector3(0.0, 0, 0), 10.5, 0.3)
		b.base = keep
		b.box(Vector3(1.6, 0.1, 1.5), Vector3(-1.9, 0.9, 0), "#40453a")
		return b.commit()), Vector3.ZERO, true)


## 이동 지휘 요새: 넓은 4궤도 차대, 2층 상부 구조, 함교, 레이더, 미사일 발사함, 방공 포탑, 주포탑
static func _b3(hull: Node3D, tur: Node3D) -> void:
	MK.inst(hull, MK.cached("b3_hull", func():
		var b = MK.new()
		var c1 = "#555b4e"
		var c2 = "#3f4439"
		var c3 = "#6a7163"
		for s in [-1.0, 1.0]:
			_track(b, 10.6, s * 2.9, 12, 0.4, 1.0)
			_track(b, 9.4, s * 1.9, 10, 0.36, 0.9)
			b.box(Vector3(10.8, 0.08, 1.9), Vector3(0, 1.08, s * 2.45), c2, Vector3.ZERO, 0.02)
			for i in 8:
				b.box(Vector3(1.24, 0.6, 0.08), Vector3(-4.6 + i * 1.3, 0.78, s * 3.3), c1 if i % 2 == 0 else c2, Vector3.ZERO, 0.02)
		## 1층 · 2층 · 경사 전면
		b.box(Vector3(10.0, 1.3, 5.2), Vector3(0, 1.6, 0), c1, Vector3.ZERO, 0.16, Vector2(0.95, 0.94))
		b.box(Vector3(1.8, 0.16, 4.9), Vector3(4.6, 1.75, 0), c3, Vector3(0, 0, -0.5), 0.04)
		b.box(Vector3(6.6, 1.0, 4.0), Vector3(-1.0, 2.7, 0), c2, Vector3.ZERO, 0.14, Vector2(0.93, 0.92))
		for s in [-1.0, 1.0]:
			for i in 5:
				b.glow = true
				b.box(Vector3(0.5, 0.2, 0.04), Vector3(-3.4 + i * 1.2, 2.8, s * 1.98), "#ffd596")
				b.glow = false
			## 측면 기관포 포탑
			_autoturret(b, Vector3(3.3, 2.25, s * 1.9), "#6a7163")
			## 뒤쪽 미사일 발사함 (비스듬히 세움)
			var keep = b.base
			b.base = Transform3D(Basis.from_euler(Vector3(0, 0, 0.75)), Vector3(-3.4, 3.9, s * 1.35))
			b.box(Vector3(2.4, 0.8, 1.1), Vector3.ZERO, "#646a56", Vector3.ZERO, 0.04)
			for sy in [-0.19, 0.19]:
				for sz in [-0.27, 0.27]:
					b.cyl(0.15, 0.15, 0.06, Vector3(1.21, sy, sz), "#a8322a", "x", 8)
			b.base = keep
			b.beam(Vector3(-3.9, 3.2, s * 1.35), Vector3(-3.5, 3.7, s * 1.35), 0.08, 0.07, c2, 5)
			b.cyl(0.16, 0.13, 1.2, Vector3(-4.6, 3.0, s * 0.8), "#1e1f1c", "y", 8)
		## 함교 탑 + 창 + 레이더 돛대
		b.box(Vector3(1.9, 1.7, 2.2), Vector3(-1.9, 4.0, 0), c1, Vector3.ZERO, 0.12, Vector2(0.86, 0.86))
		b.glow = true
		b.box(Vector3(0.04, 0.3, 1.7), Vector3(-0.98, 4.4, 0), "#9fd8ff")
		b.glow = false
		b.box(Vector3(2.1, 0.1, 2.4), Vector3(-1.9, 4.9, 0), c2)
		b.beam(Vector3(-2.2, 4.9, 0), Vector3(-2.2, 6.6, 0), 0.07, 0.04, "#2a2d30", 6)
		b.box(Vector3(0.14, 0.7, 1.9), Vector3(-2.15, 6.2, 0), "#8d959c", Vector3(0, 0.3, 0.15), 0.03)
		b.beam(Vector3(-1.5, 4.9, 0.8), Vector3(-1.6, 7.4, 0.84), 0.016, 0.008, "#1c1e1a", 4)
		b.box(Vector3(0.3, 0.07, 5.0), Vector3(1.4, 2.27, 0), "#a8322a")
		return b.commit()), Vector3.ZERO, true)
	## 방공 포탑 (체력 75%에서 사라진다)
	var aa = Node3D.new()
	aa.name = "AA"
	hull.add_child(aa)
	MK.inst(aa, MK.cached("b3_aa", func():
		var b = MK.new()
		b.cyl(0.7, 0.75, 0.2, Vector3(0, 0.1, 0), "#2b2e28", "y", 12)
		b.box(Vector3(1.1, 0.8, 1.0), Vector3(0, 0.6, 0), "#6a7163", Vector3.ZERO, 0.08)
		for z in [-0.3, 0.3]:
			b.beam(Vector3(0.2, 0.8, z), Vector3(1.3, 2.4, z), 0.07, 0.06, "#141513", 6)
		b.lathe([Vector2(0.0, 0.0), Vector2(0.5, 0.12), Vector2(0.0, 0.2)], Vector3(-0.3, 1.2, 0), "#8d959c", Vector3(0, 0, 0.5), 10)
		b.box(Vector3(0.9, 0.5, 0.5), Vector3(-0.5, 0.6, 0.75), "#b8bcb4", Vector3(0, 0, 0.6), 0.04)
		return b.commit()), Vector3(-4.2, 3.2, 0), true)
	tur.position = Vector3(0, 3.1, 0)
	MK.inst(tur, MK.cached("b3_turret", func():
		var b = MK.new()
		b.cyl(1.2, 1.3, 0.2, Vector3(2.4, 0.1, 0), "#2b2e28", "y", 14)
		b.box(Vector3(2.8, 0.95, 2.4), Vector3(2.3, 0.65, 0), "#6a7163", Vector3.ZERO, 0.16, Vector2(0.82, 0.8))
		b.box(Vector3(0.7, 0.7, 1.0), Vector3(3.9, 0.62, 0), "#3f4439", Vector3.ZERO, 0.08)
		_barrel(b, Vector3(4.1, 0.65, 0.32), 3.6, 0.12)
		_barrel(b, Vector3(4.1, 0.65, -0.32), 3.6, 0.12)
		b.cyl(0.36, 0.33, 0.22, Vector3(1.8, 1.24, -0.6), "#3f4439", "y", 10)
		return b.commit()), Vector3.ZERO, true)


## ---------- 경전차: 낮은 6륜 차체 + 작은 포탑 + 가늘고 긴 기관포 ----------
static func ltank(ally := false) -> Node3D:
	var root = Node3D.new()
	var hull = Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	MK.inst(hull, MK.cached("lt_hull_a" if ally else "lt_hull", func():
		var b = MK.new()
		var c1 = "#56633f" if ally else "#6a6b55"
		var c2 = "#434e32" if ally else "#55564a"
		b.box(Vector3(2.9, 0.5, 1.5), Vector3(0, 0.62, 0), c1, Vector3.ZERO, 0.1, Vector2(0.9, 0.86))
		b.box(Vector3(0.9, 0.1, 1.4), Vector3(1.2, 0.72, 0), "#787a62", Vector3(0, 0, -0.4), 0.03)
		b.box(Vector3(0.5, 0.3, 1.2), Vector3(1.4, 0.42, 0), c2, Vector3(0, 0, 0.5), 0.04)
		for s in [-1.0, 1.0]:
			for i in 3:
				b.cyl(0.34, 0.34, 0.3, Vector3(-0.95 + i * 0.95, 0.34, s * 0.8), "#151515", "z", 10)
				b.cyl(0.16, 0.16, 0.32, Vector3(-0.95 + i * 0.95, 0.34, s * 0.8), c2, "z", 8)
			b.box(Vector3(2.9, 0.06, 0.4), Vector3(0, 0.72, s * 0.82), c2, Vector3.ZERO, 0.02)
			b.box(Vector3(0.1, 0.1, 0.14), Vector3(1.45, 0.66, s * 0.55), "#e8e2c0")
		b.box(Vector3(0.8, 0.04, 1.0), Vector3(-0.95, 0.89, 0), "#2b2e26")
		b.box(Vector3(0.16, 0.05, 1.46), Vector3(-0.4, 0.89, 0), "#4fa3d9" if ally else "#a8322a")
		return b.commit()), Vector3.ZERO, true)
	var tur = Node3D.new()
	tur.name = "Turret"
	tur.position = Vector3(0, 0.9, 0)
	root.add_child(tur)
	MK.inst(tur, MK.cached("lt_turret_a" if ally else "lt_turret", func():
		var b = MK.new()
		b.box(Vector3(1.1, 0.36, 0.95), Vector3(-0.05, 0.19, 0), "#657249" if ally else "#757762", Vector3.ZERO, 0.08, Vector2(0.8, 0.78))
		b.box(Vector3(0.3, 0.24, 0.4), Vector3(0.6, 0.18, 0), "#55564a", Vector3.ZERO, 0.04)
		b.beam(Vector3(0.7, 0.2, 0), Vector3(2.3, 0.2, 0), 0.045, 0.04, "#22241d", 6)
		b.cyl(0.07, 0.07, 0.18, Vector3(2.25, 0.2, 0), "#101010", "x", 8)
		b.cyl(0.07, 0.07, 0.5, Vector3(1.0, 0.2, 0), "#33362c", "x", 8)
		b.cyl(0.18, 0.18, 0.05, Vector3(-0.2, 0.4, -0.2), "#868870", "y", 8)
		b.beam(Vector3(-0.45, 0.38, 0.35), Vector3(-0.5, 1.5, 0.36), 0.01, 0.006, "#1c1e1a", 4)
		for s in [-1.0, 1.0]:
			b.cyl(0.04, 0.04, 0.16, Vector3(0.2, 0.3, s * 0.5), "#55564a", "x", 6, Vector3(0, s * -0.4, 0.4))
		return b.commit()), Vector3.ZERO, true)
	return _finish(root, false)


## ---------- 이동식 지대지 미사일 발사대: 8륜 차량 + 세워 올린 4연장 발사관 ----------
static func tel() -> Node3D:
	var root = Node3D.new()
	var hull = Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	MK.inst(hull, MK.cached("tel_hull", func():
		var b = MK.new()
		var c1 = "#565c4a"
		var c2 = "#434839"
		b.box(Vector3(4.4, 0.3, 1.5), Vector3(0, 0.78, 0), "#2b2e28")
		for s in [-1.0, 1.0]:
			for x in [1.6, 0.75, -0.75, -1.6]:
				b.cyl(0.42, 0.42, 0.34, Vector3(x, 0.42, s * 0.72), "#131313", "z", 10)
				b.cyl(0.2, 0.2, 0.36, Vector3(x, 0.42, s * 0.72), c2, "z", 8)
			b.box(Vector3(0.08, 0.12, 0.2), Vector3(2.25, 0.95, s * 0.6), "#e8e2c0")
		## 운전실 (앞) + 장비함 (가운데)
		b.box(Vector3(1.1, 0.95, 1.6), Vector3(1.65, 1.35, 0), c1, Vector3.ZERO, 0.12, Vector2(0.85, 0.92))
		b.box(Vector3(0.06, 0.34, 1.3), Vector3(2.17, 1.5, 0), "#16232b")
		b.box(Vector3(0.9, 0.6, 1.5), Vector3(0.6, 1.2, 0), c2, Vector3.ZERO, 0.06)
		b.box(Vector3(0.2, 0.26, 1.64), Vector3(2.22, 0.74, 0), "#23261f", Vector3.ZERO, 0.04)
		b.box(Vector3(0.14, 0.05, 1.52), Vector3(0.1, 0.94, 0), "#a8322a")
		return b.commit()), Vector3.ZERO, true)
	var tur = Node3D.new()
	tur.name = "Turret"
	tur.position = Vector3(0, 1.25, 0)
	root.add_child(tur)
	MK.inst(tur, MK.cached("tel_launcher", func():
		var b = MK.new()
		b.cyl(0.5, 0.55, 0.16, Vector3(-0.9, -0.24, 0), "#434839", "y", 10)
		b.beam(Vector3(-0.5, -0.2, 0.4), Vector3(-0.1, 0.9, 0.4), 0.06, 0.05, "#434839", 5)
		b.beam(Vector3(-0.5, -0.2, -0.4), Vector3(-0.1, 0.9, -0.4), 0.06, 0.05, "#434839", 5)
		var keep = b.base
		b.base = Transform3D(Basis.from_euler(Vector3(0, 0, 0.8)), Vector3(-0.4, 1.0, 0))
		b.box(Vector3(3.0, 0.86, 1.2), Vector3.ZERO, "#646a56", Vector3.ZERO, 0.04)
		for sy in [-0.21, 0.21]:
			for sz in [-0.3, 0.3]:
				b.cyl(0.17, 0.17, 0.06, Vector3(1.51, sy, sz), "#a8322a", "x", 8)
				b.cyl(0.19, 0.19, 0.04, Vector3(-1.51, sy, sz), "#2e3129", "x", 8)
		for x in [-1.0, 0.0, 1.0]:
			b.box(Vector3(0.1, 0.9, 1.24), Vector3(x, 0, 0), "#4a4f41")
		b.base = keep
		return b.commit()), Vector3.ZERO, true)
	return _finish(root, false)


## ---------- 자주포 (전차 차체 + 상자형 포탑 + 치켜든 긴 포신) ----------
static func spg() -> Node3D:
	var root = Node3D.new()
	var hull = Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	MK.inst(hull, MK.cached("tank_hull", func(): return _tank_hull()), Vector3.ZERO, true)
	var tur = Node3D.new()
	tur.name = "Turret"
	tur.position = Vector3(0, 1.1, 0)
	root.add_child(tur)
	MK.inst(tur, MK.cached("spg_turret", func():
		var b = MK.new()
		var olive = "#5c6251"
		var dark = "#444a3c"
		b.box(Vector3(2.3, 0.95, 1.75), Vector3(-0.45, 0.5, 0), olive, Vector3.ZERO, 0.09, Vector2(0.9, 0.86))
		b.box(Vector3(0.5, 0.6, 1.0), Vector3(0.75, 0.45, 0), dark, Vector3(0, 0, 0.35), 0.06)
		b.box(Vector3(1.2, 0.05, 1.3), Vector3(-0.6, 0.99, 0), dark)
		for s in [-1.0, 1.0]:
			b.box(Vector3(1.5, 0.3, 0.06), Vector3(-0.5, 0.55, s * 0.84), dark, Vector3.ZERO, 0.02)
			b.cyl(0.16, 0.16, 0.04, Vector3(-0.2, 1.01, s * 0.4), "#6b7260", "y", 10)
		## 포신: 35도쯤 치켜든 긴 회전체 + 포구 제퇴기 + 주퇴 복좌기
		var keep = b.base
		b.base = Transform3D(Basis.from_euler(Vector3(0, 0, -PI / 2 + 0.6)), Vector3(0.75, 0.6, 0))
		b.lathe([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.18, 0.5), Vector2(0.12, 0.55), Vector2(0.1, 2.6), Vector2(0.16, 2.62), Vector2(0.16, 3.0), Vector2(0.08, 3.0), Vector2(0.0, 2.95)],
			Vector3.ZERO, "#3a3e33", Vector3.ZERO, 10, ["#3a3e33", "#444a3c", "#444a3c", "#2e3129", "#2e3129", "#1e201b", "#101010", "#101010"])
		b.base = keep
		b.box(Vector3(0.5, 0.3, 1.5), Vector3(-1.75, 0.3, 0), dark, Vector3.ZERO, 0.05)
		b.beam(Vector3(-1.3, 0.98, 0.6), Vector3(-1.4, 2.6, 0.62), 0.012, 0.006, "#1c1e1a", 4)
		b.box(Vector3(0.2, 0.05, 1.7), Vector3(-1.0, 0.99, 0), "#a8322a")
		return b.commit()), Vector3.ZERO, true)
	return _finish(root, false)


static func _tank_hull(ally := false) -> Mesh:
	var b = MK.new()
	var olive = "#56633f" if ally else "#5a604e"
	var dark = "#434e32" if ally else "#474c3e"
	var lite = "#69774e" if ally else "#6b7260"
	for s in [-1.0, 1.0]:
		## 궤도 + 보기륜 6 + 기동륜·유동륜
		b.box(Vector3(3.7, 0.56, 0.5), Vector3(0, 0.3, s * 1.0), "#1c1d1a", Vector3.ZERO, 0.2)
		for i in 6:
			var wx = -1.35 + i * 0.54
			b.cyl(0.23, 0.23, 0.54, Vector3(wx, 0.27, s * 1.0), "#2e302a", "z", 10)
			b.cyl(0.11, 0.11, 0.57, Vector3(wx, 0.27, s * 1.0), lite, "z", 8)
		b.cyl(0.2, 0.2, 0.55, Vector3(1.68, 0.38, s * 1.0), dark, "z", 10)
		b.cyl(0.2, 0.2, 0.55, Vector3(-1.68, 0.38, s * 1.0), dark, "z", 10)
		## 흙받이 + 조각난 측면 장갑
		b.box(Vector3(3.75, 0.06, 0.62), Vector3(0, 0.62, s * 1.0), dark, Vector3.ZERO, 0.02)
		for i in 5:
			b.box(Vector3(0.66, 0.3, 0.06), Vector3(-1.4 + i * 0.7, 0.46, s * 1.3), olive if i % 2 == 0 else dark, Vector3.ZERO, 0.02)
		## 전조등
		b.box(Vector3(0.1, 0.1, 0.14), Vector3(1.72, 0.74, s * 0.72), "#e8e2c0", Vector3.ZERO, 0.02)
	## 차체: 아래 + 위(앞이 비스듬한 전면 장갑)
	b.box(Vector3(3.3, 0.4, 1.5), Vector3(0, 0.5, 0), dark)
	b.box(Vector3(3.2, 0.42, 1.95), Vector3(-0.05, 0.86, 0), olive, Vector3.ZERO, 0.08, Vector2(0.94, 0.92))
	b.box(Vector3(0.9, 0.1, 1.8), Vector3(1.5, 0.82, 0), lite, Vector3(0, 0, -0.42), 0.03)
	b.box(Vector3(0.5, 0.3, 1.5), Vector3(1.72, 0.52, 0), dark, Vector3(0, 0, 0.5), 0.04)
	## 엔진 덮개 그릴 + 배기구 + 보조 연료통
	for i in 4:
		b.box(Vector3(0.12, 0.03, 1.1), Vector3(-0.85 - i * 0.2, 1.085, 0), "#2b2e26")
	b.box(Vector3(0.95, 0.04, 1.3), Vector3(-1.15, 1.06, 0), "#363a30")
	for s in [-1.0, 1.0]:
		b.cyl(0.07, 0.07, 0.3, Vector3(-1.72, 0.78, s * 0.55), "#1e1f1c", "x", 8)
		b.cyl(0.2, 0.2, 0.75, Vector3(-1.82, 0.98, s * 0.45), dark, "z", 10)
		b.box(Vector3(0.3, 0.03, 0.06), Vector3(-1.82, 0.98, s * 0.45 + 0.2), "#2b2e26")
	## 적군 표식 (붉은 띠) + 견인 고리 + 공구함
	b.box(Vector3(0.18, 0.05, 1.86), Vector3(-0.55, 1.07, 0), "#4fa3d9" if ally else "#a8322a")
	b.box(Vector3(0.5, 0.16, 0.3), Vector3(0.6, 1.1, -0.72), dark, Vector3.ZERO, 0.03)
	b.box(Vector3(0.08, 0.1, 0.2), Vector3(1.93, 0.5, 0.45), "#1e1f1c")
	b.box(Vector3(0.08, 0.1, 0.2), Vector3(1.93, 0.5, -0.45), "#1e1f1c")
	return b.commit()


static func _tank_turret(ally := false) -> Mesh:
	var b = MK.new()
	var olive = "#5f6c46" if ally else "#656b5a"
	var dark = "#4a5537" if ally else "#4d5244"
	var lite = "#707e54" if ally else "#757c68"
	## 포탑 본체(위가 좁다) + 앞 경사 장갑 + 포방패
	b.box(Vector3(1.75, 0.52, 1.45), Vector3(-0.1, 0.27, 0), olive, Vector3.ZERO, 0.1, Vector2(0.82, 0.8))
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.7, 0.4, 0.5), Vector3(0.62, 0.22, s * 0.42), lite, Vector3(0, s * -0.45, 0), 0.06)
		## 연막탄 발사기
		for i in 3:
			b.cyl(0.045, 0.045, 0.2, Vector3(0.3 - i * 0.14, 0.42, s * 0.72), dark, "x", 6, Vector3(0, s * -0.5, 0.5))
	b.box(Vector3(0.42, 0.38, 0.55), Vector3(0.92, 0.25, 0), dark, Vector3.ZERO, 0.06)
	## 포신: 굵기가 변하는 회전체 (배연기 + 포구 제퇴기)
	var keep = b.base
	b.base = Transform3D(Basis.from_euler(Vector3(0, 0, -PI / 2)), Vector3(1.05, 0.27, 0))
	b.lathe([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.11, 0.25), Vector2(0.1, 0.9), Vector2(0.14, 0.95), Vector2(0.14, 1.35), Vector2(0.095, 1.4), Vector2(0.088, 2.2), Vector2(0.13, 2.22), Vector2(0.13, 2.5), Vector2(0.07, 2.5), Vector2(0.0, 2.45)],
		Vector3.ZERO, "#3a3e33", Vector3.ZERO, 10, ["#3a3e33", "#3a3e33", "#3a3e33", "#2e3129", "#2e3129", "#2e3129", "#3a3e33", "#22241d", "#22241d", "#101010", "#101010"])
	b.base = keep
	## 전차장 큐폴라 + 해치 + 기관총
	b.cyl(0.27, 0.25, 0.16, Vector3(-0.3, 0.6, -0.32), dark, "y", 10)
	b.cyl(0.2, 0.2, 0.04, Vector3(-0.3, 0.7, -0.32), lite, "y", 10)
	b.cyl(0.2, 0.2, 0.04, Vector3(-0.25, 0.55, 0.36), lite, "y", 10)
	b.box(Vector3(0.3, 0.09, 0.08), Vector3(-0.1, 0.8, -0.32), "#1c1e1a", Vector3.ZERO, 0.02)
	b.beam(Vector3(0.05, 0.8, -0.32), Vector3(0.6, 0.8, -0.32), 0.02, 0.018, "#101010", 5)
	b.beam(Vector3(-0.15, 0.7, -0.32), Vector3(-0.1, 0.78, -0.32), 0.02, 0.02, "#1c1e1a", 4)
	## 뒤 적재함 + 안테나 + 반응장갑 블록
	b.box(Vector3(0.5, 0.32, 1.25), Vector3(-1.1, 0.24, 0), dark, Vector3.ZERO, 0.05)
	b.box(Vector3(0.3, 0.14, 0.5), Vector3(-1.1, 0.46, 0.2), "#5e5a44", Vector3(0, 0.2, 0), 0.04)
	b.beam(Vector3(-0.8, 0.5, 0.5), Vector3(-0.9, 2.1, 0.52), 0.012, 0.006, "#1c1e1a", 4)
	for i in 3:
		for s in [-1.0, 1.0]:
			b.box(Vector3(0.22, 0.05, 0.22), Vector3(0.25 - i * 0.26, 0.545, s * 0.2), lite, Vector3.ZERO, 0.015)
	return b.commit()


## ---------- 쿼드콥터 ----------
static func quad(led: String, body := "#2a2c30") -> Node3D:
	var root = Node3D.new()
	var b = Node3D.new()
	b.name = "Body"
	root.add_child(b)
	MK.inst(b, MK.cached("quad_" + body, func():
		var k = MK.new()
		var arms = [Vector3(0.32, 0, 0.32), Vector3(-0.32, 0, 0.32), Vector3(0.32, 0, -0.32), Vector3(-0.32, 0, -0.32)]
		for a in arms:
			k.beam(Vector3.ZERO, a, 0.035, 0.025, "#3a3d42", 6)
			k.cyl(0.05, 0.04, 0.09, a + Vector3(0, 0.01, 0), "#1c1d20", "y", 8)
			k.beam(a + Vector3(0, -0.02, 0), a * 0.9 + Vector3(0, -0.14, 0), 0.012, 0.012, "#1c1d20", 4)
		k.box(Vector3(0.34, 0.11, 0.2), Vector3.ZERO, body, Vector3.ZERO, 0.04)
		k.box(Vector3(0.2, 0.05, 0.14), Vector3(-0.02, 0.07, 0), Color(body).lightened(0.15), Vector3.ZERO, 0.02)
		k.sphere(0.06, Vector3(0.16, -0.06, 0), "#101114", Vector3.ONE, 8, 5)
		k.box(Vector3(0.16, 0.07, 0.1), Vector3(0, -0.09, 0), "#4b5a2e", Vector3.ZERO, 0.02)
		return k.commit()), Vector3.ZERO, true)
	for p in [Vector3(0.32, 0.07, 0.32), Vector3(-0.32, 0.07, 0.32), Vector3(0.32, 0.07, -0.32), Vector3(-0.32, 0.07, -0.32)]:
		ML.no_shadow(ML.cyl(b, 0.2, 0.2, 0.01, "#d4d9e0", p, Vector3.ZERO, 12, ML.mat("#d4d9e0", 0.0, 0.35)))
	ML.sph(b, 0.04, led, Vector3(0.19, 0.03, 0), Vector3.ONE, ML.mat(led, 4.0), 6)
	return _finish(root, false)


## ---------- 센트리 / 박격포 ----------
static func sentry(mortar: bool) -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("sentry_base_%s" % mortar, func():
		var k = MK.new()
		for i in 3:
			var a = i / 3.0 * TAU + 0.5
			k.beam(Vector3(0, 0.6, 0), Vector3(cos(a) * 0.72, 0.03, sin(a) * 0.72), 0.045, 0.03, "#3a3e36", 6)
			k.box(Vector3(0.16, 0.04, 0.12), Vector3(cos(a) * 0.72, 0.02, sin(a) * 0.72), "#22241f", Vector3(0, -a, 0), 0.01)
		k.cyl(0.09, 0.07, 0.14, Vector3(0, 0.6, 0), "#2b2e28", "y", 8)
		if mortar:
			k.cyl(0.52, 0.56, 0.07, Vector3(0, 0.035, 0), "#4a4f45", "y", 12)
		return k.commit()), Vector3.ZERO, true)
	var gun = Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, 0.65, 0)
	root.add_child(gun)
	MK.inst(gun, MK.cached("sentry_gun_%s" % mortar, func():
		var k = MK.new()
		if mortar:
			k.beam(Vector3(-0.12, -0.5, 0), Vector3(0.36, 0.92, 0), 0.11, 0.1, "#3a4034", 10)
			k.beam(Vector3(0.3, 0.76, 0), Vector3(0.37, 0.95, 0), 0.115, 0.115, "#2a2e26", 10)
			k.box(Vector3(0.1, 0.14, 0.24), Vector3(0.05, 0.1, 0), "#2a2e26", Vector3.ZERO, 0.02)
		else:
			k.box(Vector3(0.78, 0.34, 0.5), Vector3(0, 0.13, 0), "#5b6152", Vector3.ZERO, 0.06)
			k.box(Vector3(0.4, 0.3, 0.26), Vector3(-0.1, 0.1, 0.37), "#3c4134", Vector3.ZERO, 0.04)
			k.box(Vector3(0.3, 0.04, 0.1), Vector3(-0.1, 0.27, 0.37), "#c8a030")
			k.cyl(0.075, 0.075, 0.5, Vector3(0.62, 0.14, 0), "#2a2d27", "x", 8)
			k.cyl(0.035, 0.035, 0.7, Vector3(1.1, 0.14, 0), "#141513", "x", 6)
			k.cyl(0.055, 0.055, 0.12, Vector3(1.45, 0.14, 0), "#141513", "x", 8)
			k.box(Vector3(0.2, 0.14, 0.18), Vector3(0.1, 0.36, -0.1), "#2a2d27", Vector3.ZERO, 0.03)
		return k.commit()), Vector3.ZERO, true)
	if not mortar:
		ML.sph(gun, 0.05, "#4fa3d9", Vector3(0.21, 0.37, -0.1), Vector3.ONE, ML.mat("#4fa3d9", 3.0), 6)
	return _finish(root, false)


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


## ---------- 공격헬기 (기수가 +X). 탠덤 조종석·날개 무장·기수 기관포·마스트 레이더 ----------
static func apache() -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("apache", func():
		var b = MK.new()
		var od = "#4a5140"
		var dk = "#383e31"
		var glass = "#16232b"
		## 동체 + 기수 + 조준 장치
		b.box(Vector3(2.7, 0.95, 0.86), Vector3(0.35, 0.0, 0), od, Vector3.ZERO, 0.2)
		b.box(Vector3(1.1, 0.62, 0.7), Vector3(1.95, -0.14, 0), od, Vector3(0, 0, -0.08), 0.2, Vector2(0.8, 0.8))
		b.sphere(0.2, Vector3(2.55, -0.2, 0), "#101214", Vector3(1, 1, 1.1), 10, 6)
		b.cyl(0.13, 0.13, 0.22, Vector3(2.5, 0.0, 0), dk, "y", 8)
		## 계단식 탠덤 조종석 (앞: 사수, 뒤: 조종사) + 창틀
		b.box(Vector3(0.85, 0.5, 0.6), Vector3(1.5, 0.42, 0), glass, Vector3(0, 0, -0.3), 0.08, Vector2(0.8, 0.75))
		b.box(Vector3(0.95, 0.6, 0.66), Vector3(0.72, 0.62, 0), glass, Vector3(0, 0, -0.12), 0.08, Vector2(0.85, 0.75))
		b.box(Vector3(0.06, 0.5, 0.68), Vector3(1.12, 0.55, 0), od, Vector3(0, 0, -0.2))
		b.box(Vector3(1.9, 0.05, 0.1), Vector3(1.05, 0.83, 0), od, Vector3(0, 0, -0.17))
		## 엔진 덮개 둘 + 흡기구 + 배기구
		for s in [-1.0, 1.0]:
			b.cyl(0.29, 0.26, 1.6, Vector3(-0.25, 0.38, s * 0.62), od, "x", 10)
			b.cyl(0.2, 0.2, 0.06, Vector3(0.57, 0.38, s * 0.62), "#0e0f10", "x", 10)
			b.box(Vector3(0.5, 0.3, 0.34), Vector3(-1.15, 0.42, s * 0.66), "#23261f", Vector3(0, s * 0.25, 0), 0.06)
			## 짧은 날개 + 로켓 포드 + 대전차 미사일 넷
			b.box(Vector3(0.75, 0.09, 1.25), Vector3(0.1, -0.12, s * 0.95), dk, Vector3(0, 0, 0), 0.03, Vector2(0.9, 0.9))
			b.cyl(0.17, 0.17, 0.95, Vector3(0.15, -0.36, s * 1.3), "#2c3027", "x", 10)
			b.cyl(0.13, 0.13, 0.03, Vector3(0.64, -0.36, s * 1.3), "#0e0f10", "x", 10)
			b.box(Vector3(0.3, 0.12, 0.06), Vector3(0.1, -0.24, s * 1.3), dk)
			for q in [[-0.09, -0.3], [0.09, -0.3], [-0.09, -0.46], [0.09, -0.46]]:
				b.cyl(0.055, 0.055, 0.8, Vector3(0.18, q[1], s * 0.78 + q[0]), "#b8bcb4", "x", 6)
				b.sphere(0.055, Vector3(0.58, q[1], s * 0.78 + q[0]), "#22241f", Vector3(1.4, 1, 1), 6, 4)
			b.box(Vector3(0.3, 0.14, 0.26), Vector3(0.1, -0.25, s * 0.78), dk)
			## 착륙 장치
			b.beam(Vector3(1.0, -0.35, s * 0.4), Vector3(1.15, -0.98, s * 0.72), 0.05, 0.04, dk, 5)
			b.cyl(0.2, 0.2, 0.15, Vector3(1.15, -1.0, s * 0.74), "#111211", "z", 10)
		## 기수 아래 30mm 기관포
		b.box(Vector3(0.3, 0.22, 0.24), Vector3(1.3, -0.6, 0), dk, Vector3.ZERO, 0.05)
		b.beam(Vector3(1.4, -0.66, 0), Vector3(2.2, -0.72, 0), 0.04, 0.035, "#0e0f10", 6)
		## 꼬리: 붐 + 뒤로 젖힌 수직 꼬리날개 + 수평 꼬리날개 + 꼬리 바퀴
		b.beam(Vector3(-0.9, 0.12, 0), Vector3(-3.7, 0.38, 0), 0.32, 0.12, od, 8)
		b.box(Vector3(0.75, 1.35, 0.09), Vector3(-3.62, 0.9, 0), od, Vector3(0, 0, 0.42), 0.03, Vector2(0.6, 1.0))
		b.box(Vector3(0.5, 0.05, 1.7), Vector3(-3.75, 0.22, 0), dk, Vector3.ZERO, 0.02)
		b.beam(Vector3(-3.3, 0.2, 0), Vector3(-3.4, -0.4, 0), 0.04, 0.03, dk, 5)
		b.cyl(0.13, 0.13, 0.1, Vector3(-3.4, -0.42, 0), "#111211", "z", 8)
		## 로터 기둥 + 마스트 위 레이더 돔
		b.cyl(0.16, 0.13, 0.6, Vector3(0.1, 0.75, 0), dk, "y", 8)
		b.lathe([Vector2(0.0, 0.0), Vector2(0.4, 0.06), Vector2(0.46, 0.2), Vector2(0.34, 0.34), Vector2(0.0, 0.38)], Vector3(0.1, 1.42, 0), "#3a4033", Vector3.ZERO, 12)
		b.cyl(0.06, 0.06, 0.3, Vector3(0.1, 1.25, 0), dk, "y", 6)
		return b.commit()), Vector3.ZERO, true)
	var rot = Node3D.new()
	rot.name = "Rotor"
	rot.position = Vector3(0.1, 1.1, 0)
	root.add_child(rot)
	MK.inst(rot, MK.cached("apache_rotor", func():
		var b = MK.new()
		for i in 4:
			var a = i * PI / 2 + 0.3
			b.box(Vector3(4.4, 0.04, 0.26), Vector3(cos(a) * 2.25, 0, sin(a) * 2.25), "#16181a", Vector3(0, -a, 0))
		b.cyl(0.2, 0.2, 0.12, Vector3.ZERO, "#16181a", "y", 8)
		return b.commit()))
	ML.no_shadow(ML.cyl(rot, 4.5, 4.5, 0.02, "#c8d0c0", Vector3.ZERO, Vector3.ZERO, 24, ML.mat("#c8d0c0", 0.0, 0.1)))
	var tr = Node3D.new()
	tr.name = "TailRotor"
	tr.position = Vector3(-3.72, 1.15, 0.13)
	root.add_child(tr)
	MK.inst(tr, MK.cached("apache_tail", func():
		var b = MK.new()
		b.box(Vector3(0.14, 1.35, 0.03), Vector3.ZERO, "#16181a")
		b.box(Vector3(1.35, 0.14, 0.03), Vector3.ZERO, "#16181a", Vector3(0, 0, 0.5))
		return b.commit()))
	ML.no_shadow(ML.sph(root, 0.07, "#ff3a2a", Vector3(-3.9, 1.6, 0), Vector3.ONE, ML.mat("#ff3a2a", 4.0), 6))
	return _finish(root, false)


## ---------- 거치 기관총 진지 (삼각대 + 모래주머니, Gun이 돈다) ----------
static func hmg() -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("hmg_base", func():
		var k = MK.new()
		for i in 3:
			var a = i / 3.0 * TAU + PI / 3
			k.beam(Vector3(0, 0.85, 0), Vector3(cos(a) * 0.75, 0.03, sin(a) * 0.75), 0.04, 0.028, "#2e312b", 6)
			k.box(Vector3(0.18, 0.04, 0.12), Vector3(cos(a) * 0.75, 0.02, sin(a) * 0.75), "#1c1e1a", Vector3(0, -a, 0), 0.01)
		k.cyl(0.07, 0.06, 0.18, Vector3(0, 0.86, 0), "#232520", "y", 8)
		## 탄약통 더미
		k.box(Vector3(0.36, 0.24, 0.2), Vector3(-0.55, 0.12, 0.5), "#4b5a2e", Vector3(0, 0.4, 0), 0.03)
		k.box(Vector3(0.36, 0.24, 0.2), Vector3(-0.6, 0.12, 0.24), "#4b5a2e", Vector3(0, 0.1, 0), 0.03)
		k.box(Vector3(0.34, 0.22, 0.2), Vector3(-0.57, 0.36, 0.38), "#56603a", Vector3(0, 0.7, 0), 0.03)
		return k.commit()), Vector3.ZERO, true)
	var gun = Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, 0.98, 0)
	root.add_child(gun)
	MK.inst(gun, MK.cached("hmg_gun", func():
		var k = MK.new()
		k.box(Vector3(0.62, 0.17, 0.13), Vector3(0.05, 0.03, 0), "#1f2022", Vector3.ZERO, 0.025)
		k.cyl(0.045, 0.045, 0.62, Vector3(0.66, 0.04, 0), "#2a2c2e", "x", 8)
		k.cyl(0.022, 0.022, 0.5, Vector3(1.2, 0.04, 0), "#111213", "x", 6)
		k.cyl(0.036, 0.03, 0.1, Vector3(1.47, 0.04, 0), "#111213", "x", 8)
		for z in [-0.07, 0.07]:
			k.beam(Vector3(-0.26, 0.04, z), Vector3(-0.44, 0.04, z), 0.02, 0.02, "#1f2022", 5)
			k.beam(Vector3(-0.44, -0.05, z), Vector3(-0.44, 0.13, z), 0.024, 0.024, "#5a4326", 6)
		k.box(Vector3(0.26, 0.2, 0.16), Vector3(0.05, -0.02, 0.17), "#4b5a2e", Vector3.ZERO, 0.025)
		k.box(Vector3(0.2, 0.03, 0.1), Vector3(0.05, 0.1, 0.09), "#c8a030")
		k.box(Vector3(0.04, 0.42, 0.62), Vector3(0.32, 0.14, 0), "#3a3e36", Vector3.ZERO, 0.02)
		k.box(Vector3(0.05, 0.12, 0.16), Vector3(0.32, 0.16, 0), "#111213")
		return k.commit()), Vector3.ZERO, true)
	return _finish(root, false)


static func crate() -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("crate", func():
		var k = MK.new()
		k.box(Vector3(1.3, 0.9, 1.1), Vector3(0, 0.45, 0), "#56603a", Vector3.ZERO, 0.06)
		k.box(Vector3(1.36, 0.1, 1.16), Vector3(0, 0.86, 0), "#454d2e", Vector3.ZERO, 0.03)
		k.box(Vector3(1.33, 0.16, 1.13), Vector3(0, 0.55, 0), "#f2c21b")
		for x in [-0.4, 0.4]:
			k.box(Vector3(0.09, 0.93, 1.14), Vector3(x, 0.46, 0), "#2e3320")
		k.box(Vector3(0.14, 0.02, 0.5), Vector3(0, 0.92, 0), "#e8e4d8")
		k.box(Vector3(0.5, 0.02, 0.14), Vector3(0, 0.92, 0), "#e8e4d8")
		for z in [-0.58, 0.58]:
			k.box(Vector3(0.3, 0.06, 0.05), Vector3(0, 0.62, z), "#1c1d1a")
		return k.commit()), Vector3.ZERO, true)
	return _finish(root, false)


## 강하용 원형 낙하산. 원점이 어깨 멜빵 자리이고 산개한 캐노피가 그 위 3.4 m에 뜬다
static func chute() -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("chute", func():
		var k = MK.new()
		var R = 2.0
		var H = 1.05
		var top = 3.4
		var outer: Array = []
		var inner: Array = []
		var cols: Array = []
		for i in 7:
			var a = i / 6.0 * PI / 2
			outer.append(Vector2(maxf(R * cos(a), 0.14), top + H * sin(a)))
			inner.append(Vector2(maxf((R - 0.04) * cos(PI / 2 - a), 0.14), top + (H - 0.04) * sin(PI / 2 - a)))
			cols.append("#565f3d" if i % 2 == 0 else "#4a5235")
		## 바깥 면(위장색 띠) + 안쪽 면(어두운 색). 꼭대기는 배기 구멍
		k.lathe(outer, Vector3.ZERO, "#565f3d", Vector3.ZERO, 16, cols)
		k.lathe(inner, Vector3.ZERO, "#2c3122", Vector3.ZERO, 16)
		## 산줄 8가닥과 멜빵
		for i in 8:
			var a = i / 8.0 * TAU
			k.beam(Vector3(0.12 * cos(a), 0.05, 0.12 * sin(a)), Vector3(R * 0.98 * cos(a), top + 0.02, R * 0.98 * sin(a)), 0.014, 0.014, "#cfcab8", 4)
		k.box(Vector3(0.16, 0.1, 0.3), Vector3(0, 0, 0), "#23241f", Vector3.ZERO, 0.02)
		return k.commit()), Vector3.ZERO, true)
	return _finish(root, false)


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


## F-35형 다목적 전투기 (+X가 기수): 짧고 통통한 동체, 단발 엔진, 사다리꼴 날개, 바깥으로 기운 쌍꼬리
static func _fighter() -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("f35", func():
		var b = MK.new()
		var g1 = Color("#7b838a")
		var g2 = Color("#626a72")
		var g3 = Color("#4f575f")
		## 동체(가운데가 불룩) + 기수 + 금빛 조종석
		b.box(Vector3(2.3, 0.46, 0.9), Vector3(-0.15, 0.0, 0), g1, Vector3.ZERO, 0.17)
		b.box(Vector3(1.0, 0.36, 0.56), Vector3(1.15, 0.02, 0), g1, Vector3.ZERO, 0.14, Vector2(0.7, 0.6))
		b.lathe([Vector2(0.22, 0.0), Vector2(0.13, 0.4), Vector2(0.0, 0.75)], Vector3(1.6, 0.0, 0), g2, Vector3(0, 0, -PI / 2), 8)
		b.sphere(0.21, Vector3(1.05, 0.24, 0), "#4a3d1c", Vector3(2.1, 0.8, 0.9), 10, 5, 0.0)
		b.box(Vector3(0.9, 0.16, 0.36), Vector3(0.1, 0.24, 0), g2, Vector3.ZERO, 0.06)
		## 단발 엔진 노즐
		b.cyl(0.24, 0.2, 0.4, Vector3(-1.45, 0.0, 0), "#2a2d30", "x", 10)
		for s2 in [-1.0, 1.0]:
			## 흡입구 (동체 옆, 앞으로 벌어진 모양)
			b.box(Vector3(0.7, 0.3, 0.26), Vector3(0.55, -0.04, s2 * 0.48), g2, Vector3(0, s2 * -0.16, 0), 0.07)
			b.box(Vector3(0.05, 0.2, 0.2), Vector3(0.9, -0.04, s2 * 0.55), "#101214")
			## 사다리꼴 주날개 · 수평 꼬리날개
			b.quad(Vector3(0.5, 0.0, s2 * 0.42), Vector3(-0.35, 0.0, s2 * 1.5), Vector3(-0.85, 0.0, s2 * 1.5), Vector3(-0.9, 0.0, s2 * 0.42), g1, Vector3.UP, Transform3D.IDENTITY, true)
			b.quad(Vector3(-0.4, 0.012, s2 * 1.46), Vector3(-0.8, 0.012, s2 * 1.46), Vector3(-0.85, 0.012, s2 * 0.6), Vector3(-0.6, 0.012, s2 * 0.6), g3, Vector3.UP)
			b.quad(Vector3(-0.95, 0.0, s2 * 0.42), Vector3(-1.35, 0.0, s2 * 1.0), Vector3(-1.72, 0.0, s2 * 1.0), Vector3(-1.6, 0.0, s2 * 0.42), g2, Vector3.UP, Transform3D.IDENTITY, true)
			## 바깥으로 기운 수직 꼬리날개
			b.quad(Vector3(-0.6, 0.2, s2 * 0.36), Vector3(-1.35, 0.2, s2 * 0.36), Vector3(-1.5, 0.92, s2 * 0.72), Vector3(-1.12, 0.92, s2 * 0.72), g2, Vector3(0, 0.4, s2), Transform3D.IDENTITY, true)
		return b.commit()))
	var fl = ML.sph(root, 0.2, "#ffb046", Vector3(-1.8, 0.0, 0), Vector3(2.4, 1, 1), ML.add_mat("#ffb046", 0.9), 8)
	fl.name = "Flame"
	_no_shadow_all(root)
	return root


## A-10형 공격기 (+X가 기수): 곧은 날개, 동체 뒤 위쪽의 쌍발 엔진, 수평 꼬리날개 양 끝의 수직 꼬리, 기수 기관포
static func _attacker() -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("a10", func():
		var b = MK.new()
		var g1 = Color("#6b7378")
		var g2 = Color("#565e63")
		var g3 = Color("#444b50")
		## 길쭉한 동체 + 둥근 기수 + 물방울 조종석
		b.beam(Vector3(-1.9, 0.02, 0), Vector3(1.5, 0.0, 0), 0.26, 0.3, g1, 10, true)
		b.sphere(0.3, Vector3(1.55, -0.02, 0), g1, Vector3(1.5, 0.95, 0.95), 10, 6)
		b.sphere(0.24, Vector3(0.95, 0.26, 0), "#1b2a33", Vector3(1.7, 0.85, 0.85), 10, 5, 0.0)
		## 기수 30mm 기관포 (살짝 왼쪽으로 치우쳐 있다)
		b.cyl(0.07, 0.07, 0.5, Vector3(2.1, -0.16, -0.05), "#101214", "x", 8)
		b.box(Vector3(0.5, 0.12, 0.16), Vector3(1.6, -0.24, -0.05), g3, Vector3.ZERO, 0.04)
		## 곧은 주날개 (끝이 아래로 꺾임) + 무장 걸이
		for s2 in [-1.0, 1.0]:
			b.box(Vector3(0.95, 0.09, 2.0), Vector3(0.1, -0.12, s2 * 1.15), g1, Vector3(s2 * 0.05, 0, 0), 0.03, Vector2(0.92, 0.92))
			b.box(Vector3(0.7, 0.06, 0.3), Vector3(0.05, -0.2, s2 * 2.22), g2, Vector3(s2 * -0.5, 0, 0), 0.02)
			for k in [0.7, 1.15, 1.6]:
				b.cyl(0.07, 0.07, 0.6, Vector3(0.15, -0.28, s2 * k), g3, "x", 6)
			## 바퀴 덮개
			b.beam(Vector3(-0.1, -0.2, s2 * 0.75), Vector3(0.75, -0.22, s2 * 0.75), 0.11, 0.07, g2, 6, true)
			## 엔진: 동체 뒤 위쪽에 올려 단 굵은 통
			b.cyl(0.3, 0.27, 1.05, Vector3(-0.95, 0.42, s2 * 0.5), g2, "x", 10)
			b.cyl(0.24, 0.24, 0.04, Vector3(-0.42, 0.42, s2 * 0.5), "#101214", "x", 10)
			b.cyl(0.2, 0.17, 0.12, Vector3(-1.52, 0.42, s2 * 0.5), "#2a2d30", "x", 10)
			b.box(Vector3(0.5, 0.26, 0.14), Vector3(-0.95, 0.2, s2 * 0.34), g1, Vector3.ZERO, 0.04)
			## 수평 꼬리날개 끝의 수직 꼬리
			b.box(Vector3(0.6, 0.7, 0.07), Vector3(-2.05, 0.3, s2 * 0.98), g2, Vector3.ZERO, 0.02, Vector2(0.75, 1.0))
		b.box(Vector3(0.62, 0.07, 2.0), Vector3(-2.05, 0.02, 0), g1, Vector3.ZERO, 0.02)
		return b.commit()))
	for s2 in [-1.0, 1.0]:
		var fl = ML.sph(root, 0.14, "#ffb046", Vector3(-1.72, 0.42, s2 * 0.5), Vector3(1.8, 1, 1), ML.add_mat("#ffb046", 0.7), 8)
		fl.name = "Flame" if s2 < 0 else "Flame2"
	_no_shadow_all(root)
	return root


## 지원 항공기 (+X가 기수). kind: "f35"(폭격) / "a10"(기총소사). big=true면 대형 폭격기(융단 포격)
static func jet(big := false, kind := "f35") -> Node3D:
	if not big:
		return _attacker() if kind == "a10" else _fighter()
	return _bomber()


## B-52형 대형 폭격기 (+X가 기수): 가늘고 긴 동체, 뒤로 젖힌 긴 날개, 날개 밑 쌍발 엔진 포드 넷, 높은 수직 꼬리
static func _bomber() -> Node3D:
	var root = Node3D.new()
	MK.inst(root, MK.cached("bomber", func():
		var b = MK.new()
		var g1 = Color("#6f777c")
		var g2 = Color("#596166")
		var g3 = Color("#43494e")
		## 동체 + 둥근 기수 + 조종석 창
		b.beam(Vector3(-2.6, 0.05, 0), Vector3(2.1, 0.0, 0), 0.24, 0.34, g1, 10, true)
		b.sphere(0.34, Vector3(2.15, -0.02, 0), g1, Vector3(1.5, 0.95, 0.95), 10, 6)
		b.box(Vector3(0.3, 0.14, 0.5), Vector3(2.2, 0.2, 0), "#16232b", Vector3(0, 0, -0.5), 0.04)
		b.box(Vector3(1.6, 0.14, 0.5), Vector3(0.2, -0.3, 0), g3, Vector3.ZERO, 0.05)
		for s2 in [-1.0, 1.0]:
			## 뒤로 젖힌 긴 주날개 (끝으로 갈수록 좁다)
			b.quad(Vector3(0.9, 0.12, s2 * 0.3), Vector3(-1.5, 0.05, s2 * 3.7), Vector3(-1.95, 0.05, s2 * 3.7), Vector3(-0.5, 0.12, s2 * 0.3), g1, Vector3.UP, Transform3D.IDENTITY, true)
			b.quad(Vector3(0.6, 0.135, s2 * 0.5), Vector3(-1.5, 0.062, s2 * 3.5), Vector3(-1.75, 0.062, s2 * 3.5), Vector3(0.2, 0.135, s2 * 0.5), g2, Vector3.UP)
			## 엔진 포드 둘 (포드마다 엔진 둘): 날개 앞으로 내민 지주에 매달려 있다
			for q in [[1.2, 0.05], [2.4, -0.75]]:
				var ez: float = s2 * q[0]
				var ex: float = q[1]
				b.box(Vector3(0.7, 0.26, 0.07), Vector3(ex + 0.25, -0.1, ez), g2, Vector3(0, 0, 0.25), 0.02)
				for dz in [-0.13, 0.13]:
					b.cyl(0.12, 0.1, 0.7, Vector3(ex + 0.4, -0.3, ez + dz), g3, "x", 8)
					b.cyl(0.09, 0.09, 0.03, Vector3(ex + 0.76, -0.3, ez + dz), "#0e0f10", "x", 8)
			## 날개 끝 보조 연료통
			b.beam(Vector3(-1.9, 0.0, s2 * 3.3), Vector3(-1.2, 0.0, s2 * 3.3), 0.07, 0.09, g2, 6, true)
			## 수평 꼬리날개
			b.quad(Vector3(-2.0, 0.1, s2 * 0.2), Vector3(-2.7, 0.1, s2 * 1.4), Vector3(-3.0, 0.1, s2 * 1.4), Vector3(-2.75, 0.1, s2 * 0.2), g2, Vector3.UP, Transform3D.IDENTITY, true)
		## 높은 수직 꼬리날개
		b.box(Vector3(0.95, 1.5, 0.07), Vector3(-2.55, 0.95, 0), g2, Vector3(0, 0, 0.28), 0.02, Vector2(0.55, 1.0))
		return b.commit()))
	for s2 in [-1.0, 1.0]:
		for q in [[1.2, 0.05], [2.4, -0.75]]:
			var fl = ML.sph(root, 0.13, "#ffb046", Vector3(q[1] - 0.05, -0.3, s2 * q[0]), Vector3(1.8, 0.8, 2.0), ML.add_mat("#ffb046", 0.6), 8)
			fl.name = "Flame%d_%d" % [int(q[0] * 10), int(s2)]
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
