extends Node3D
## 전투 월드. 논리는 프로토타입(index.html)의 update()를 거의 그대로 옮겼다.
## 논리 좌표 (x, y)는 게임 단위, 3D 위치는 (x*K, h, y*K).

signal ended(win: bool, rows: Array, total: int, stars: int)
signal leveled(opts: Array)

const Data := preload("res://scripts/data.gd")
const WG := preload("res://scripts/worldgen.gd")
const ML := preload("res://scripts/meshlib.gd")
const AC := preload("res://scripts/actors.gd")

const K := WG.K
const WORLD := WG.WORLD
const TS := 50.0
const TN := 60
const AAR := 430.0 ## 방공포 교란 반경
const PEND := 0.6  ## 겹치는 부호 대기 시간
const LIFT := 1.05 ## 탄환 높이(m)
const DW := {speed = 560.0, range = 250.0, kb = 10.0}

var hud: Control
var cam: Camera3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var world_root: Node3D
var dyn: Node3D
var overlay_im := ImmediateMesh.new()
var tracer_im := ImmediateMesh.new()
var bar_im := ImmediateMesh.new()
var parts_mm := MultiMesh.new()
var gems_mm := MultiMesh.new()
var scorch_mm := MultiMesh.new()
var fx_pool: Array = []
var light_pool: Array = []
var label_pool: Array = []
var font: SystemFont

## ---------- 상태 ----------
var map: Dictionary = {}
var active := false
var preview_mode := false
var t := 0.0
var rt := 0.0
var run := false
var pause := ""
var over := false
var kills := 0
var shake := 0.0
var hs := 0.0
var flash := 0.0
var spawnT := 2.0
var combo := 0
var comboT := 0.0
var best := 0
var bonus := 0
var aim = null
var heat := 0
var rcd := 0.0
var rcall = null
var silent := 0
var alertN := 0
var susN := 0
var last_seen = null
var intel := false
var reinf_mul := 1.0
var cd_mul := 1.0
var p: Dictionary = {}
var strats: Array = []
var en: Array = []
var bul: Array = []
var eb: Array = []
var gems: Array = []
var crates: Array = []
var calls: Array = []
var timers: Array = []
var zones: Array = []
var marks: Array = []
var mines: Array = []
var turrets: Array = []
var drones: Array = []
var mis: Array = []
var lobs: Array = []
var vort: Array = []
var tele: Array = []
var arcs: Array = []
var fx: Array = []
var scorch: Array = []
var fl: Array = []
var pt: Array = []
var grid: Array = []
var ext: Dictionary = {}
var last_shot := 0.0
var uid_n := 0
var player_node: Node3D
var shield_node: MeshInstance3D
var muzzle_light: OmniLight3D
var call_flare: Node3D
## 진화 연출: evoT 동안 슬로모션·카메라 줌인·대형 문구
var evoT := 0.0
var evo_name := ""
var evo_col := Color("#f2c21b")
var beams: Array = []
## 지원 전투기·낙하 폭탄
var jets: Array = []
## 통신 드론(진화): 장착 지원요청을 자동 호출. cd는 플레이어와 별도
var comms = null
var bombs: Array = []
var siegeN := 0
const EVO_COL := {comms = "#62d0f0", ar = "#ffd04a", sg = "#ff5a1a", lmg = "#ffb03a", rail = "#6fe8ff", aim = "#a6dc68", gren = "#ff9d1a", drone = "#62d0f0", taser = "#8fc8ff"}
var heli_node: Node3D
var lobT := 0.0

## 모스 입력 상태
var M := {down = false, t0 = 0.0, buf = "", last = 0.0, pid = 0, fired = false, miss = 0, thr = 0.15, queue = null, pend = null, pendT = 0.0}
## 이동 입력 (터치 조이스틱)
var joy := {id = -1, ox = 0.0, oy = 0.0, x = 0.0, y = 0.0}
var aim_touch := -1


func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "Apple SD Gothic Neo", "sans-serif"])
	font.font_weight = 700
	env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.92
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.05
	e.fog_enabled = true
	e.fog_density = 0.0025
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.rotation_degrees = Vector3(-52, -35, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 40.0
	cam.far = 260.0
	add_child(cam)
	cam.current = true
	world_root = Node3D.new()
	add_child(world_root)
	dyn = Node3D.new()
	add_child(dyn)
	_mk_imm(overlay_im, ML.vcol_mat(false, false), 1)
	_mk_imm(tracer_im, ML.vcol_mat(true, false), 3)
	_mk_imm(bar_im, ML.vcol_mat(false, true), 5)
	_mk_mm(parts_mm, ML.sph_mesh(1.0, 6, 3), 420, true, ML.vcol_mat(false, false))
	var gm = ML.vcol_mat(false, false)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mk_mm(gems_mm, ML.sph_mesh(0.14, 4, 2), 400, true, gm)
	var sm = ML.mat("#120e0b", 0.0, 0.42, true)
	_mk_mm(scorch_mm, ML.cyl_mesh(1.0, 1.0, 0.01, 14), 60, false, sm)
	for i in 28:
		var mi = MeshInstance3D.new()
		mi.mesh = ML.sph_mesh(1.0, 14, 7)
		var fm = ML.add_mat("#ffb046", 1.0)
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		mi.material_override = fm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		fx_pool.append(mi)
	for i in 6:
		var l = OmniLight3D.new()
		l.light_color = Color("#ffb060")
		l.visible = false
		add_child(l)
		light_pool.append(l)
	for i in 40:
		var lb = _label(28)
		lb.visible = false
		add_child(lb)
		label_pool.append(lb)


func _mk_imm(im: ImmediateMesh, m: Material, prio: int) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = im
	m.render_priority = prio
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	add_child(mi)


func _mk_mm(mm: MultiMesh, mesh: Mesh, n: int, colors: bool, m: Material) -> void:
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)


func _label(size: int) -> Label3D:
	var lb = Label3D.new()
	lb.font = font
	lb.font_size = size
	lb.outline_size = 10
	lb.outline_modulate = Color(0.03, 0.035, 0.04, 0.95)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.pixel_size = 0.02
	lb.render_priority = 10
	lb.outline_render_priority = 9
	return lb


static func p3(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x * K, h, y * K)


static func d2(a, b) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()


static func ang_d(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


static func turn_to(a: float, b: float, k: float) -> float:
	return a + ang_d(b, a) * minf(1.0, k)


## ---------- 맵 준비 ----------
func _clear() -> void:
	for c in world_root.get_children():
		c.queue_free()
	for c in dyn.get_children():
		c.queue_free()
	heli_node = null
	player_node = null


func _setup_env(bm: Dictionary) -> void:
	var e = env.environment
	e.background_color = Color(bm.sky)
	e.ambient_light_color = Color(bm.amb)
	e.ambient_light_energy = 0.42
	e.fog_light_color = Color(bm.fog)
	sun.light_color = Color(bm.sun)
	sun.light_energy = 1.05 if not bm.get("snow", false) else 0.8


func _build(seed_v: int) -> void:
	_clear()
	map = WG.gen_map(seed_v)
	_setup_env(map.biome)
	WG.build_world(world_root, map)
	for o in map.objs:
		var n = WG.build_struct(o)
		world_root.add_child(n)
		o.node = n
		var lb = _label(26)
		lb.position = p3(o.x, o.y, 6.0 if o.type == "nest" else 10.5 if o.type == "cap" else 4.6 if o.type == "aa" else 4.0)
		world_root.add_child(lb)
		o.label = lb


## 로비 배경: 출발 지점에 서 있는 대원
func preview(seed_v: int) -> void:
	active = false
	preview_mode = true
	_build(seed_v)
	player_node = AC.soldier("pl")
	player_node.position = p3(map.start.x, map.start.y)
	dyn.add_child(player_node)
	lobT = 0.0


var diff := 1


func new_game(seed_v: int, d := 1) -> void:
	diff = d
	preview_mode = false
	_build(seed_v)
	var w: Dictionary = Data.weapon(Save.d.w)
	t = 0.0; rt = 0.0; run = true; pause = ""; over = false; kills = 0; shake = 0.0; hs = 0.0; flash = 0.0; spawnT = 2.0; evoT = 0.0; comms = null; _evo_snd = -1.0
	combo = 0; comboT = 0.0; best = 0; bonus = 0; aim = null; heat = 0; rcd = 0.0; rcall = null; silent = 0; alertN = 0; susN = 0
	last_seen = null; intel = false; reinf_mul = 1.0; cd_mul = 1.0
	p = {x = map.start.x, y = map.start.y, r = 11.0, hp = 120.0, maxhp = 120.0, w = w, aim = -PI / 2, face = -PI / 2, fx = 0.0, fy = -1.0,
		ammo = w.mag, reload = 0.0, fireT = 0.0, xp = 0, lvl = 1, next = 5, lives = 2, shieldT = 0.0, boostT = 0.0, inv = 1.5, hurtT = 0.0,
		grenT = 2.0, tasT = 2.0, up = {}, evo = {}, m = {}, muz = 0.0, mv = false}
	strats = []
	for id in Save.d.eq:
		var s: Dictionary = Data.strat(id).duplicate()
		s.t = 0.0
		strats.append(s)
	for a in [en, bul, eb, gems, crates, calls, timers, zones, marks, mines, turrets, drones, mis, lobs, vort, tele, arcs, fx, scorch, fl, pt, beams, jets, bombs]:
		a.clear()
	grid = []
	grid.resize(TN * TN)
	for i in TN * TN:
		grid[i] = []
	ext = {x = map.ext.x, y = map.ext.y, r = 100.0, state = "locked", t = 0.0, ship = 0.0}
	recalc()
	for o in map.objs:
		if o.type == "term":
			o.code = term_code()
	player_node = AC.soldier("pl")
	dyn.add_child(player_node)
	shield_node = MeshInstance3D.new()
	shield_node.mesh = ML.sph_mesh(1.0, 16, 8)
	shield_node.material_override = ML.mat("#62d0f0", 1.2, 0.25, true)
	shield_node.scale = Vector3(1.3, 1.5, 1.3)
	shield_node.position.y = 0.9
	shield_node.visible = false
	player_node.add_child(shield_node)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color("#ffc070")
	muzzle_light.omni_range = 5.0
	muzzle_light.position = Vector3(1.2, 1.3, 0.15)
	muzzle_light.visible = false
	player_node.add_child(muzzle_light)
	## 증원 요청 중인 무전병 위로 올라가는 붉은 신호탄
	call_flare = AC.beacon_light(Color("#ff3a2a"))
	call_flare.scale = Vector3(1, 0.55, 1)
	var fl_light = OmniLight3D.new()
	fl_light.light_color = Color("#ff4030")
	fl_light.omni_range = 7.0
	fl_light.light_energy = 2.0
	fl_light.position = Vector3(0, 3.0, 0)
	call_flare.add_child(fl_light)
	call_flare.visible = false
	dyn.add_child(call_flare)
	populate()
	M.buf = ""; M.down = false; M.queue = null; M.miss = 0; M.pend = null
	active = true
	banner("주 임무: 단말기 2곳 해킹. 들키지 마라")


func recalc() -> void:
	var L = func(k): return p.up.get(k, 0)
	var m: Dictionary = p.m
	m.dmg = 1 + 0.18 * L.call("dmg"); m.rate = 1 + 0.12 * L.call("rate"); m.pierce = L.call("pierce"); m.mag = 1 + 0.3 * L.call("mag")
	m.rl = 1 - 0.1 * L.call("mag"); m.multi = L.call("multi"); m.spd = 1 + 0.08 * L.call("spd")
	m.magnet = 60.0 * (1 + 0.4 * L.call("magnet")); m.cd = (1 - 0.08 * L.call("cd")) * cd_mul; m.blast = 1 + 0.12 * L.call("blast")
	var mh: float = 120 + 20 * L.call("hp")
	if mh > p.maxhp:
		p.hp = minf(mh, p.hp + mh - p.maxhp + 10)
		p.maxhp = mh
	var want: int = 0
	if L.call("drone") > 0:
		want = (2 if L.call("drone") >= 4 else 1) + (2 if p.evo.has("drone") else 0)
	var have = drones.filter(func(d): return d.perm).size()
	while have < want:
		var dn = AC.quad("#4fa3d9", "#3a4450")
		dyn.add_child(dn)
		drones.append({a = randf() * TAU, fireT = 0.0, perm = true, life = 1.0, x = p.x, y = p.y, node = dn})
		have += 1


func term_code() -> String:
	while true:
		var c = ""
		for i in 6:
			c += "." if randf() < 0.5 else "-"
		var bad: bool = Data.SOS.begins_with(c)
		for s in Data.STRATS:
			if c.begins_with(s.code) or s.code.begins_with(c):
				bad = true
		if not bad:
			return c
	return "......"


func mag_size() -> int:
	return roundi(p.w.mag * p.m.mag)


## ---------- 유틸 ----------
func later(dt: float, fn: Callable) -> void:
	timers.append({t = dt, fn = fn})


func floater(x: float, y: float, txt: String, col := Color.WHITE, sz := 14) -> void:
	if fl.size() >= 40:
		return
	for lb in label_pool:
		if not lb.visible:
			lb.visible = true
			lb.text = txt
			lb.modulate = col
			lb.font_size = int(sz * 2.4)
			fl.append({x = x, y = y, t = 0.0, lb = lb})
			return


func banner(s: String) -> void:
	if hud:
		hud.banner(s)


func puff(x: float, y: float, c: Color, n: int, sp := 90.0) -> void:
	for i in n:
		if pt.size() >= 400:
			return
		var a = randf() * TAU
		var v = sp * (0.3 + randf())
		pt.append({x = x, y = y, vx = cos(a) * v, vy = sin(a) * v, t = 0.0, d = 0.25 + randf() * 0.3, c = c, r = 1.5 + randf() * 2.5, g = 0.0, h = 0.6})


func is_dest(o) -> bool:
	return o.type == "nest" or o.type == "aa"


func in_aa() -> bool:
	if not active:
		return false
	for o in map.objs:
		if o.type == "aa" and not o.done and d2(o, p) < AAR:
			return true
	return false


func rock_push(o: Dictionary) -> void:
	var cx = int(o.x / 100)
	var cy = int(o.y / 100)
	for j in range(cy - 1, cy + 2):
		for i in range(cx - 1, cx + 2):
			if i < 0 or j < 0 or i >= 30 or j >= 30:
				continue
			for k in map.rg[j * 30 + i]:
				if k.has("hw"):
					var nx = clampf(o.x, k.x - k.hw, k.x + k.hw)
					var ny = clampf(o.y, k.y - k.hh, k.y + k.hh)
					var dx: float = o.x - nx
					var dy: float = o.y - ny
					var d = sqrt(dx * dx + dy * dy)
					if d > 0:
						if d < o.r:
							o.x = nx + dx / d * o.r
							o.y = ny + dy / d * o.r
					else:
						var l: float = o.x - (k.x - k.hw)
						var rt2: float = k.x + k.hw - o.x
						var tp: float = o.y - (k.y - k.hh)
						var bt: float = k.y + k.hh - o.y
						var mn = minf(minf(l, rt2), minf(tp, bt))
						if mn == l: o.x = k.x - k.hw - o.r
						elif mn == rt2: o.x = k.x + k.hw + o.r
						elif mn == tp: o.y = k.y - k.hh - o.r
						else: o.y = k.y + k.hh + o.r
				else:
					var dx: float = o.x - k.x
					var dy: float = o.y - k.y
					var d = maxf(0.001, sqrt(dx * dx + dy * dy))
					var mm: float = k.r * 0.9 + o.r
					if d < mm:
						o.x = k.x + dx / d * mm
						o.y = k.y + dy / d * mm


## 높이 16 이상인 상자(건물·컨테이너)가 시야와 탄환을 막는다
func blocked(x: float, y: float) -> bool:
	var ci = int(x / 100)
	var cj = int(y / 100)
	for j in range(cj - 1, cj + 2):
		for i in range(ci - 1, ci + 2):
			if i < 0 or j < 0 or i >= 30 or j >= 30:
				continue
			for k in map.rg[j * 30 + i]:
				if k.has("hw") and k.h >= 16 and absf(x - k.x) < k.hw and absf(y - k.y) < k.hh:
					return true
	return false


func los(ax: float, ay: float, bx: float, by: float) -> bool:
	los_n += 1
	var i0 = maxi(0, int(minf(ax, bx) / 100) - 1)
	var i1 = mini(29, int(maxf(ax, bx) / 100) + 1)
	var j0 = maxi(0, int(minf(ay, by) / 100) - 1)
	var j1 = mini(29, int(maxf(ay, by) / 100) + 1)
	var dx = bx - ax
	var dy = by - ay
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			for k in map.rg[j * 30 + i]:
				if not k.has("hw") or k.h < 16:
					continue
				var t0 = 0.0
				var t1 = 1.0
				var out = false
				for ax2 in 2:
					var p0 = ax if ax2 == 0 else ay
					var dd = dx if ax2 == 0 else dy
					var lo: float = (k.x - k.hw) if ax2 == 0 else (k.y - k.hh)
					var hi: float = (k.x + k.hw) if ax2 == 0 else (k.y + k.hh)
					if absf(dd) < 1e-9:
						if p0 < lo or p0 > hi:
							out = true
							break
					else:
						var u = (lo - p0) / dd
						var v = (hi - p0) / dd
						if u > v:
							var w = u
							u = v
							v = w
						t0 = maxf(t0, u)
						t1 = minf(t1, v)
						if t0 > t1:
							out = true
							break
				if not out:
					return false
	return true


## ---------- 적 ----------
func spawn(type: String, x = null, y = null, ang = null):
	var T: Dictionary = Data.ET[type]
	if x == null:
		var a: float = randf() * TAU if ang == null else ang + (randf() - 0.5) * 0.7
		var d = 520.0 + randf() * 90.0
		x = clampf(p.x + cos(a) * d, 20, WORLD - 20)
		y = clampf(p.y + sin(a) * d, 20, WORLD - 20)
		if Vector2(x - p.x, y - p.y).length() < 300:
			return null
	var hp: float = T.hp * (1 + t / 300.0) * (0.85 + 0.2 * diff)
	var node: Node3D
	if type == "tk":
		node = AC.tank()
	elif type == "dr":
		node = AC.quad("#ff3020")
	else:
		node = AC.soldier(type)
	dyn.add_child(node)
	var lb = _label(30)
	lb.visible = false
	node.add_child(lb)
	lb.position.y = 3.6 if type == "tk" else 2.6
	var e = {type = type, T = T, x = float(x), y = float(y), r = T.r, hp = hp, maxhp = hp, vx = 0.0, vy = 0.0, atk = 0.0, flash = 0.0, shoot = 1 + randf() * 2,
		ph = randf() * TAU, frz = 0.0, burn = 0.0, st = "alert", face = randf() * TAU, aw = 1.0, seen = 0.0, chk = 0.0, sv = 0.0, alT = 0.0, home = "post",
		node = node, lb = lb, walk = 0.0, nT = -9.0, uid = uid_n, px = float(x), py = float(y), bf = 0.0}
	uid_n += 1
	en.append(e)
	return e


func guard(type: String, x: float, y: float, face: float):
	var e = spawn(type, clampf(x, 30, WORLD - 30), clampf(y, 30, WORLD - 30))
	if e == null:
		return null
	rock_push(e)
	e.st = "post"; e.home = "post"; e.px = e.x; e.py = e.y; e.face = face; e.bf = face; e.aw = 0.0
	if type == "tk":
		e.ha = face
	return e


## 경비병·전초기지·순찰조 배치. 출발 지점 주변은 비워 둔다
func populate() -> void:
	var s0: Vector2 = map.start
	var far = func(x, y, d): return Vector2(x - s0.x, y - s0.y).length() > d
	var mix = func():
		var r = randf()
		return "ru" if r < 0.42 else "rf" if r < 0.82 else "sh"
	for o in map.objs:
		var n = (7 if is_dest(o) else 5) + diff - 1
		for i in n:
			var a = i / float(n) * TAU + randf() * 0.4
			var d = (75.0 if is_dest(o) else 60.0) + randf() * 70
			guard(mix.call(), o.x + cos(a) * d, o.y + sin(a) * d, a)
		if is_dest(o):
			var a = randf() * TAU
			guard("tk", o.x + cos(a) * 150, o.y + sin(a) * 150, a)
	var c = 0
	for tr in 300:
		if c >= 5:
			break
		var x = 250 + randf() * (WORLD - 500)
		var y = 250 + randf() * (WORLD - 500)
		var near_obj = false
		for o in map.objs:
			if Vector2(o.x - x, o.y - y).length() < 380:
				near_obj = true
		if not far.call(x, y, 650) or near_obj:
			continue
		c += 1
		var n = 3 + randi() % 3
		for i in n:
			var a = i / float(n) * TAU + randf() * 0.5
			var d = 30 + randf() * 50
			guard(mix.call(), x + cos(a) * d, y + sin(a) * d, a)
	c = 0
	for tr in 300:
		if c >= 10 + diff * 4:
			break
		var cx = 300 + randf() * (WORLD - 600)
		var cy = 300 + randf() * (WORLD - 600)
		if not far.call(cx, cy, 850):
			continue
		c += 1
		var route: Array = []
		var rad = 220 + randf() * 180
		var a0 = randf() * TAU
		for i in 4:
			var a = a0 + i / 4.0 * TAU
			route.append(Vector2(clampf(cx + cos(a) * rad, 60, WORLD - 60), clampf(cy + sin(a) * rad, 60, WORLD - 60)))
		var size = 3 + randi() % 3
		var lead = null
		for i in size:
			var e = guard("rf" if i == 0 and randf() < 0.5 else mix.call(), route[0].x + i * 14, route[0].y + i * 10, 0.0)
			if e == null:
				continue
			e.st = "patrol"; e.home = "patrol"; e.rt = route; e.ri = 1; e.lead = lead; e.slot = i
			if lead == null:
				lead = e


func hit_enemy(e: Dictionary, d: float, strat := false, ap := false) -> void:
	if e.hp <= 0:
		return
	if e.T.has("armor") and not strat and not ap:
		d *= e.T.armor
	var un: bool = e.st != "alert" and e.st != "call"
	if un and not strat:
		d *= 2.5
	e.hp -= d
	e.flash = 0.08
	if un and e.hp > 0:
		alert_e(e)
	if d >= 30 and randf() < 0.6:
		floater(e.x + (randf() - 0.5) * 14, e.y, str(roundi(d)), Color("#f2c21b") if strat else Color.WHITE, 15 if strat else 11)


func kill_enemy(e: Dictionary) -> void:
	kills += 1
	if is_same(e, rcall):
		rcall = null
		rcd = maxf(rcd, 8.0)
		## 보상: 지원요청 재사용 대기를 남은 시간의 30% (최소 3초) 줄인다
		var cut = false
		for s in strats:
			if s.t > 0:
				s.t = maxf(0.0, s.t - maxf(3.0, s.t * 0.3))
				cut = true
		banner("증원 요청 차단" + (" · 지원요청 대기 단축" if cut else ""))
		floater(e.x, e.y, "증원 요청 차단", Color("#a6dc68"), 16)
		Synth.beep(988, 0.08, "square", 0.04)
		Synth.beep(1319, 0.14, "square", 0.04, 0.0, 0.08)
	elif e.st != "alert" and e.st != "call":
		silent += 1
		floater(e.x, e.y, "은밀 처치", Color("#a6dc68"), 13)
	combo += 1
	comboT = 2.6
	best = maxi(best, combo)
	if combo % 50 == 0:
		bonus += 5
		p.hp = minf(p.maxhp, p.hp + 12)
		if combo % 100 == 0:
			banner("%d 연속 처치" % combo)
		floater(p.x, p.y, "+5 골드", Color("#f2c21b"), 17)
		Synth.beep(1000, 0.1); Synth.beep(1500, 0.2)
	puff(e.x, e.y, Color("#ff9d1a") if e.type == "tk" else Color("#8a2a20"), 18 if e.type == "tk" else 5)
	if e.type == "tk":
		fx.append({x = e.x, y = e.y, r = 60.0, t = 0.0, d = 0.5})
		gems.append({x = e.x, y = e.y, v = 0, lv = true, pull = false})
		hs = 0.08
		shake = 10.0
		Synth.noise(0.6, 0.25, 400)
	elif gems.size() < 360:
		gems.append({x = e.x, y = e.y, v = e.T.xp, lv = false, pull = false})
	else:
		p.xp += e.T.xp
	if is_instance_valid(e.node):
		e.node.queue_free()


func area_dmg(x: float, y: float, r: float, d: float) -> int:
	var k = 0
	for e in en:
		if e.hp <= 0:
			continue
		if Vector2(e.x - x, e.y - y).length() < r + e.r:
			hit_enemy(e, d, true)
			if e.hp <= 0:
				k += 1
	for o in map.objs:
		if is_dest(o) and not o.done and Vector2(o.x - x, o.y - y).length() < r + o.r:
			o.hp -= d
	return k


func explode(x: float, y: float, r: float, d: float, o := {}) -> int:
	if not o.get("fixed", false):
		r *= p.m.blast
		d *= p.m.blast
	make_noise(x, y, 220.0 if o.get("small", false) else 450.0)
	var k = area_dmg(x, y, r, d)
	for e in en:
		var dx: float = e.x - x
		var dy: float = e.y - y
		var q = maxf(1.0, sqrt(dx * dx + dy * dy))
		if q < r + e.r:
			var kb: float = o.get("kb", 160.0) / (4.0 if e.type == "tk" else 1.0)
			e.vx += dx / q * kb
			e.vy += dy / q * kb
	if not o.get("noFF", false) and Vector2(p.x - x, p.y - y).length() < r and p.shieldT <= 0 and p.inv <= 0:
		hurt(minf(d * 0.12, o.get("ffCap", 18.0)))
		floater(p.x, p.y, "아군 오사", Color("#ff8a7a"))
	fx.append({x = x, y = y, r = r, t = 0.0, d = 0.3 if o.get("small", false) else 0.45, c = o.get("c", null)})
	if not o.get("small", false):
		if scorch.size() > 50:
			scorch.pop_front()
		scorch.append({x = x, y = y, r = r * 0.6})
		shake = minf(16.0, shake + r / 12.0)
		Synth.noise(0.5, 0.22, 500)
		_vib(25)
		puff(x, y, Color("#ffd75a"), 8, 200)
		for i in 4:
			if pt.size() < 400:
				pt.append({x = x + (randf() - 0.5) * r * 0.6, y = y + (randf() - 0.5) * r * 0.4, vx = (randf() - 0.5) * 30, vy = (randf() - 0.5) * 30, t = 0.0, d = 0.9 + randf() * 0.5, c = Color("#2c2c2e"), r = r * 0.12, g = r * 0.32, h = 0.5})
	if k >= 6:
		floater(x, y, "%d명 격파" % k, Color("#e2412f") if k >= 15 else Color("#f2c21b"), 24 if k >= 15 else 18)
		hs = maxf(hs, 0.14 if k >= 15 else 0.07)
		if k >= 15:
			flash = 0.25
	return k


func enemy_blast(x: float, y: float, r: float, d: float) -> void:
	fx.append({x = x, y = y, r = r, t = 0.0, d = 0.4})
	shake = minf(12.0, shake + 5)
	Synth.noise(0.35, 0.18, 600)
	if Vector2(p.x - x, p.y - y).length() < r:
		hurt(d)


func hurt(d: float) -> void:
	if p.shieldT > 0 or p.inv > 0 or over:
		return
	p.hp -= d
	p.hurtT = 0.2
	if p.hp <= 0:
		if p.lives > 0:
			p.lives -= 1
			p.hp = p.maxhp
			p.inv = 3.0
			banner("증원 강하")
			flash = 0.3
			explode(p.x, p.y, 170, 400, {noFF = true, fixed = true, kb = 400.0})
		else:
			end_game(false)


func pick_from(x: float, y: float, range: float, min_d: float):
	var b = null
	var bs = -1
	for e in en:
		var d = Vector2(e.x - x, e.y - y).length()
		if d > range or d < min_d:
			continue
		var c = 4 if e.type == "tk" else 1
		for f in en:
			if not is_same(f, e) and absf(f.x - e.x) < 85 and absf(f.y - e.y) < 85:
				c += 1
		if c > bs:
			bs = c
			b = e
	if b != null:
		return Vector2(b.x, b.y)
	for o in map.objs:
		if is_dest(o) and not o.done and Vector2(o.x - x, o.y - y).length() < range:
			return Vector2(o.x, o.y)
	return null


func pick_target() -> Vector2:
	var tg = pick_from(p.x, p.y, 330, 95)
	return tg if tg != null else Vector2(p.x + p.fx * 170, p.y + p.fy * 170)


func auto_target(s: Dictionary) -> Dictionary:
	if s.aim == "near":
		var d = 125.0 if s.id == "mines" else 55.0
		return {x = p.x + p.fx * d, y = p.y + p.fy * d, ang = 0.0}
	var tg = pick_target()
	var a = atan2(tg.y - p.y, tg.x - p.x)
	if s.id == "strafe":
		return {x = p.x + cos(a) * 45, y = p.y + sin(a) * 45, ang = a}
	if s.id == "air":
		var b = randf() * TAU
		return {x = tg.x - cos(b) * 62, y = tg.y - sin(b) * 62, ang = b}
	if s.id == "napalm":
		var b = a + PI / 2
		return {x = tg.x - cos(b) * 116, y = tg.y - sin(b) * 116, ang = b}
	return {x = tg.x, y = tg.y, ang = 0.0}


## 가장 가까운 적. 격자(TS 단위 칸)를 가운데 칸부터 바깥 고리 순으로 훑고,
## 남은 고리가 지금까지 찾은 거리보다 멀면 멈춘다. need_los면 엄폐물(높이 16+)에 가린 적은 건너뛴다.
## 격자는 매 프레임 update()에서 다시 채워진다 (그 사이 새로 생긴 적은 다음 프레임부터 잡힌다)
const MAX_ER := 30.0
## 디버그: 탐색 과정 기록 (칸, 시야에 막힌 적, 고른 적)과 시야 검사 횟수
var dbg_trace := false
var trace = null
var los_n := 0
## 플레이어 시야 캐시: 적마다 결과를 0.1~0.2초 기억한다 (벽 뒤에 적이 몰려 있을 때 매 프레임 전부 다시 검사하지 않도록)
func _sees(x: float, y: float, e: Dictionary, cache: bool) -> bool:
	if not cache:
		return los(x, y, e.x, e.y)
	if t < e.get("lvT", -1.0):
		return e.lv
	e.lv = los(x, y, e.x, e.y)
	e.lvT = t + 0.1 + randf() * 0.1
	return e.lv


func nearest(x: float, y: float, range: float, nests: bool, need_los := false, tr := false, cache := false):
	var b = null
	var bd = range
	var rec = null
	if tr:
		rec = {x = x, y = y, cells = [], blocked = [], rings = 0}
	var cx = int(clampf(x, 0, WORLD - 1) / TS)
	var cy = int(clampf(y, 0, WORLD - 1) / TS)
	var maxr = int(ceil((range + MAX_ER) / TS))
	for ring in maxr + 1:
		## 이 고리 칸에 있는 적까지의 최소 거리 하한
		if (ring - 1) * TS - MAX_ER > bd:
			break
		if rec != null:
			rec.rings = ring
		for j in range(cy - ring, cy + ring + 1):
			if j < 0 or j >= TN:
				continue
			var edge = j == cy - ring or j == cy + ring
			var k = cx - ring
			while k <= cx + ring:
				if k >= 0 and k < TN:
					if rec != null:
						rec.cells.append(Vector2i(k, j))
					for e in grid[j * TN + k]:
						if e.hp <= 0:
							continue
						var d: float = Vector2(e.x - x, e.y - y).length() - e.r
						if d < bd:
							if not need_los or _sees(x, y, e, cache):
								bd = d
								b = e
							elif rec != null:
								rec.blocked.append(e)
				k += 1 if edge else maxi(1, ring * 2)
	if nests:
		for o in map.objs:
			if is_dest(o) and not o.done:
				var d: float = Vector2(o.x - x, o.y - y).length() - o.r
				if d < bd:
					bd = d
					b = o
	if rec != null:
		rec.pick = b
		trace = rec
	return b


func in_cone(x: float, y: float, a: float, range: float, half: float):
	var b = null
	var bd = range
	var cand: Array = en.filter(func(e): return e.hp > 0)
	for o in map.objs:
		if is_dest(o) and not o.done:
			cand.append(o)
	for o in cand:
		var dx: float = o.x - x
		var dy: float = o.y - y
		var d = sqrt(dx * dx + dy * dy)
		if d - o.r > bd:
			continue
		if absf(ang_d(atan2(dy, dx), a)) > half + atan2(o.r, d):
			continue
		if not los(x, y, o.x, o.y):
			continue
		bd = d - o.r
		b = o
	return b


func shoot(x: float, y: float, a: float, w: Dictionary, dmg: float, pierce: int, ex := {}) -> void:
	var b = {x = x, y = y, vx = cos(a) * w.speed, vy = sin(a) * w.speed, life = w.range / w.speed * 1.15, dmg = dmg, pierce = pierce, kb = w.kb, ap = w.get("ap", false), hit = []}
	b.merge(ex)
	bul.append(b)


## ---------- 소음·발각·증원 ----------
func make_noise(x: float, y: float, r: float, src = null) -> void:
	if not active:
		return
	if src != null:
		if t - src.get("nT", -9.0) < 0.35:
			return
		src.nT = t
	for e in en:
		if e.hp <= 0 or e.st == "alert" or e.st == "call":
			continue
		var d = Vector2(e.x - x, e.y - y).length()
		if d > r:
			continue
		if d < r * 0.35 or (e.st == "sus" and d < r * 0.6):
			alert_e(e, true)
		else:
			e.st = "sus"
			e.inv = Vector2(x + (randf() - 0.5) * 60, y + (randf() - 0.5) * 60)
			e.aw = maxf(e.aw, 0.5)
			e.lookT = 0.0


func alert_e(e: Dictionary, quiet := false) -> void:
	if e.st == "alert" or e.st == "call" or e.hp <= 0:
		return
	e.st = "alert"; e.aw = 1.0; e.seen = 0.0; e.alT = 1.6
	last_seen = Vector2(p.x, p.y)
	if not quiet:
		for f in en:
			if not is_same(f, e) and f.st != "alert" and f.st != "call" and Vector2(f.x - e.x, f.y - e.y).length() < 200:
				alert_e(f, true)
	if rcall == null and rcd <= 0 and e.type != "tk" and e.type != "dr" and ext.state != "wait" and ext.state != "land":
		e.st = "call"
		e.callT = 4.5
		e.callMax = 4.5
		rcall = e
		banner("적이 증원을 요청 중! 무전병을 처치하라")
		Synth.beep(300, 0.3, "sawtooth", 0.05, 200)


func reinforce(c: Dictionary) -> void:
	rcall = null
	heat += 1
	rcd = (26.0 + heat * 2) / reinf_mul
	## 대규모 증원: 3번에 나눠 한 방향에서 몰려온다
	var n = roundi(minf(60, 22 + heat * 8) * reinf_mul)
	var a = atan2(c.y - p.y, c.x - p.x)
	banner("적 증원 도착 (부대 파괴로 병력 감소)" if reinf_mul < 1 else "적 증원 부대 도착")
	Synth.beep(240, 0.4, "sawtooth", 0.06, -80)
	for wv in 3:
		var m = n / 3 + (n % 3 if wv == 0 else 0)
		var last = wv == 2
		later(2.5 + wv * 1.8, func():
			for i in m:
				if en.size() >= 300:
					break
				var r = randf()
				spawn("dr" if heat >= 2 and r < 0.15 else "ru" if r < 0.6 else "rf" if r < 0.86 else "sh", null, null, a + (randf() - 0.5) * 0.6)
			last_seen = Vector2(p.x, p.y)
			if last and ((heat >= 2 and reinf_mul >= 1) or heat >= 4):
				spawn("tk", null, null, a))


## 구역 점령 중 증원 파도: 무전 요청 없이 바로 온다. 적 부대 파괴 시 절반
func _siege_wave() -> void:
	var n = maxi(4, roundi(minf(26, 10 + heat * 3) * reinf_mul))
	siegeN += n
	var a = randf() * TAU
	for i in n:
		if en.size() >= 300:
			break
		var r = randf()
		spawn("dr" if r < 0.15 else "ru" if r < 0.55 else "rf" if r < 0.85 else "sh", null, null, a)
	last_seen = Vector2(p.x, p.y)


## 적이 플레이어를 얼마나 잘 보는지 0~1
func see_p(e: Dictionary, d: float, dx: float, dy: float) -> float:
	var vis: float = e.T.vis
	if d > vis or p.inv > 2:
		return 0.0
	if e.st != "alert" and e.st != "call" and d > 36 and absf(ang_d(atan2(dy, dx), e.face)) > 0.85:
		return 0.0
	if not los(e.x, e.y, p.x, p.y):
		return 0.0
	return 1.0 - d / vis * 0.75


## ---------- 지원요청 ----------
## 실제 폭발 지점마다 표시하는 경고 원 (r = 실제 피해 반경)
func warn(x: float, y: float, r: float, dt: float, col := Color("#ff3a2a")) -> void:
	calls.append({x = x, y = y, r = r, t = dt, max = dt, col = col, node = null, pod = null, w = true})


## 전투기가 (x, y)를 ang 방향으로 t_over초 뒤에 지나간다. 소리 + 땅 그림자
func flyby(x: float, y: float, ang: float, t_over: float, big := false) -> void:
	var v = 420.0 if big else 560.0
	var n = AC.jet(big)
	n.scale = Vector3.ONE * (1.8 if big else 1.4)
	dyn.add_child(n)
	jets.append({x = x - cos(ang) * v * t_over, y = y - sin(ang) * v * t_over, vx = cos(ang) * v, vy = sin(ang) * v, ang = ang, life = t_over + 1.4, big = big, alt = 7.0 if big else 5.5, node = n})
	## 다가오며 커지는 제트 굉음 + 지나간 뒤 낮아지는 음 (도플러 흉내)
	var lead = maxf(0.0, t_over - 0.7)
	Synth.noise(1.6, 0.14 if big else 0.11, 500 if big else 900, lead)
	Synth.beep(160 if big else 420, 1.1, "sawtooth", 0.03, -260, lead + 0.35)
	Synth.beep(90, 1.2, "sawtooth", 0.04, -30, lead + 0.3)


## 폭탄: land_t초에 땅에 닿도록 fall초 동안 떨어진다
func drop_bomb(x: float, y: float, land_t: float, alt := 5.5, fall := 0.4) -> void:
	later(maxf(0.0, land_t - fall), func():
		var n = AC.bomb()
		dyn.add_child(n)
		bombs.append({x = x, y = y, t = 0.0, d = fall, alt = alt, node = n}))


func beacon(x: float, y: float, r: float, dt: float, col: String, drop := false) -> void:
	var c = Color(col)
	var node = AC.beacon_light(c)
	node.position = p3(x, y)
	dyn.add_child(node)
	var pd = null
	if drop:
		pd = AC.pod()
		dyn.add_child(pd)
	calls.append({x = x, y = y, r = r, t = dt, max = dt, col = c, node = node, pod = pd})
	Synth.beep(300, dt * 0.9, "sine", 0.03, 600)


func exec(s: Dictionary, T: Dictionary) -> void:
	var B: float = p.m.blast
	var x: float = T.x
	var y: float = T.y
	var ca = cos(T.ang)
	var sa = sin(T.ang)
	floater(p.x, p.y, s.name, Color("#f2c21b"), 16)
	match s.id:
		"air":
			beacon(x + ca * 62, y + sa * 62, 0, 1.1, "#ff4d4d")
			flyby(x, y, T.ang, 0.75)
			for i in 3:
				var bx = x + ca * i * 62
				var by = y + sa * i * 62
				warn(bx, by, 75 * B, 1.1 + i * 0.13)
				drop_bomb(bx, by, 1.1 + i * 0.13)
				later(1.1 + i * 0.13, func(): explode(bx, by, 75, 180))
		"strafe":
			flyby(x, y, T.ang, 0.55)
			for i in 10:
				var bx = x + ca * i * 34
				var by = y + sa * i * 34
				warn(bx, by, 40 * B, 0.6 + i * 0.05)
				later(0.6 + i * 0.05, func():
					explode(bx, by, 40, 85, {small = i % 2 == 1})
					beams.append({x0 = bx - ca * 60 + randf_range(-8, 8), y0 = by - sa * 60, x1 = bx, y1 = by, t = 0.0, d = 0.12, w = 0.3, c = Color("#ffd27a")}))
			Synth.beep(200, 0.9, "sawtooth", 0.05, 300, 0.5)
		"napalm":
			beacon(x + ca * 116, y + sa * 116, 0, 1.3, "#ff9d1a")
			flyby(x, y, T.ang, 0.95)
			for i in 5:
				warn(x + ca * i * 58, y + sa * i * 58, 55 * B, 1.3, Color("#ff9d1a"))
				drop_bomb(x + ca * i * 58, y + sa * i * 58, 1.3)
			later(1.3, func():
				for i in 5:
					zones.append({x = x + ca * i * 58, y = y + sa * i * 58, r = 55 * B, life = 7.0, dps = 55 * B, k = "fire"})
				Synth.noise(0.8, 0.2, 900)
				shake = 8.0)
		"carpet":
			beacon(x, y, 0, 2.0, "#ff4d4d")
			var ba = randf() * TAU
			flyby(x - cos(ba) * 120, y - sin(ba) * 120, ba, 1.7, true)
			for i in 14:
				var a = randf() * TAU
				var d = sqrt(randf()) * 170
				var bx = x + cos(a) * d
				var by = y + sin(a) * d
				warn(bx, by, 62 * B, 2 + i * 0.18)
				drop_bomb(bx, by, 2 + i * 0.18, 7.0, 0.5)
				later(2 + i * 0.18, func(): explode(bx, by, 62, 140))
		"turret", "mortar":
			var mortar: bool = s.id == "mortar"
			beacon(x, y, 45, 0.8, "#4fa3d9", true)
			later(0.8, func():
				explode(x, y, 48, 90, {noFF = true})
				var n = AC.sentry(mortar)
				n.position = p3(x, y)
				dyn.add_child(n)
				var life = 16.0 if mortar else 20.0
				turrets.append({x = x, y = y, life = life, max = life, fireT = 0.5 if mortar else 0.0, aim = 0.0, k = "mortar" if mortar else "gun", node = n}))
		"supply":
			beacon(x, y, 45, 0.8, "#86c94e", true)
			later(0.8, func():
				explode(x, y, 45, 70, {noFF = true})
				var n = AC.crate()
				n.position = p3(x, y)
				dyn.add_child(n)
				crates.append({x = x, y = y, node = n}))
		"heal":
			zones.append({x = x, y = y, r = 85.0, life = 8.0, k = "heal"})
			Synth.beep(500, 0.3, "sine", 0.05, 300)
		"mines":
			for i in 10:
				var a = randf() * TAU
				var d = 15 + randf() * 95
				var n = Node3D.new()
				ML.cyl(n, 0.28, 0.32, 0.12, "#4b513d", Vector3(0, 0.06, 0), Vector3.ZERO, 10)
				var led = ML.sph(n, 0.06, "#ff3a2a", Vector3(0, 0.14, 0), Vector3.ONE, ML.mat("#ff3a2a", 4.0), 6)
				led.name = "Led"
				n.position = p3(x + cos(a) * d, y + sin(a) * d)
				dyn.add_child(n)
				mines.append({x = x + cos(a) * d, y = y + sin(a) * d, arm = 0.8, node = n})
		"shield":
			p.shieldT = 6.0
			explode(p.x, p.y, 120, 45, {noFF = true, kb = 360.0, c = Color("#7fe3ff")})
		"stun":
			beacon(x, y, 140 * B, 0.8, "#ffffff")
			later(0.8, func():
				var r = 140 * B
				for e in en:
					if Vector2(e.x - x, e.y - y).length() < r + e.r:
						e.frz = 2.5 if e.type == "tk" else 4.5
						hit_enemy(e, 40, true)
				fx.append({x = x, y = y, r = r, t = 0.0, d = 0.5, c = Color.WHITE})
				flash = 0.35
				Synth.noise(0.3, 0.25, 3000)
				shake = 8.0)
		"drone":
			for i in 2:
				var dn = AC.quad("#f2c21b", "#4a4030")
				dyn.add_child(dn)
				drones.append({a = i * PI, fireT = 0.0, life = 20.0, perm = false, x = p.x, y = p.y, node = dn})
		"missiles":
			var tg = en.duplicate()
			tg.sort_custom(func(a, b): return a.hp > b.hp)
			for i in 6:
				var n = Node3D.new()
				ML.box(n, Vector3(0.5, 0.12, 0.12), "#d9dde2", Vector3.ZERO)
				ML.sph(n, 0.18, "#ffb046", Vector3(-0.35, 0, 0), Vector3.ONE, ML.add_mat("#ffb046", 0.9), 6)
				n.visible = false
				dyn.add_child(n)
				mis.append({x = p.x, y = p.y, a = -PI / 2 + (i - 2.5) * 0.5, tg = tg[i % maxi(1, tg.size())] if tg.size() else null, life = 3.5, d = i * 0.08, node = n})
			Synth.noise(0.4, 0.15, 1500)
		"gunship":
			beacon(x, y, 60, 1.6, "#ff4d4d")
			later(1.6, func(): marks.append({x = x, y = y, life = 8.0, ft = 0.0}))
		"thermo":
			beacon(x, y, 190 * B, 1.2, "#ff9d1a")
			warn(x, y, 125 * B, 4.7)
			later(1.2, func():
				vort.append({x = x, y = y, t = 3.5, r = 190 * B})
				later(3.5, func(): explode(x, y, 125, 400, {kb = 300.0})))
		"moab":
			beacon(x, y, 270 * B, 4.0, "#ff4d4d")
			banner("초대형 폭탄 투하. 대피하라")
			later(4.0, func():
				flash = 0.6
				hs = 0.2
				explode(x, y, 270, 1800, {ffCap = 70.0, kb = 500.0})
				shake = 26.0
				for i in 6:
					var a = i / 6.0 * TAU
					later(0.1 + i * 0.04, func(): fx.append({x = x + cos(a) * 150, y = y + sin(a) * 150, r = 90.0, t = 0.0, d = 0.5})))


func complete_obj(o: Dictionary) -> void:
	o.done = true
	Synth.beep(660, 0.12); Synth.beep(880, 0.12)
	later(0.12, func(): Synth.beep(1100, 0.25))
	p.hp = minf(p.maxhp, p.hp + 20)
	floater(o.x, o.y, "+40 골드", Color("#f2c21b"), 17)
	match o.type:
		"cap":
			intel = true
			for q in map.objs:
				q.known = true
			banner("통신탑 점령: 구역과 적 위치가 지도에 표시된다")
		"nest":
			reinf_mul = 0.5
			banner("적 부대 파괴: 적 증원 병력 감소")
		"aa":
			cd_mul = 0.75
			for s in strats:
				s.t *= 0.75
			recalc()
			banner("방공포 파괴: 지원요청 재사용 대기 25% 감소")
		_:
			var ms: Array = map.objs.filter(func(q): return q.type == "term")
			var md = ms.filter(func(q): return q.done).size()
			if md >= ms.size():
				ext.state = "call"
				banner("주 임무 완수. 탈출 지점으로")
			else:
				banner("주 임무 %d / %d" % [md, ms.size()])
	if o.type == "term" and o.node:
		var scr: MeshInstance3D = o.node.get_node("Live/Screen")
		scr.material_override = ML.mat("#86c94e", 2.5)
	if is_dest(o) and o.node:
		o.node.get_node("Live").visible = false
		o.node.get_node("Dead").visible = true


func gain_xp(v: int) -> void:
	p.xp += v
	if p.xp >= p.next and pause == "" and not over:
		p.xp -= p.next
		p.lvl += 1
		p.next = roundi(4 + p.lvl * 3)
		level_up()


func _evo_live(e: Dictionary) -> bool:
	if p.evo.has(e.id):
		return false
	if e.get("any", false):
		return true
	if e.has("w"):
		return e.w == p.w.id
	return p.up.get(e.sub, 0) > 0


func level_up() -> void:
	pause = "lvl"
	release_key(true)
	joy.id = -1
	Synth.beep(700, 0.15); Synth.beep(1050, 0.3)
	var opts: Array = []
	for e in Data.EVOS:
		if _evo_live(e):
			var ok = true
			for k in e.need:
				if p.up.get(k, 0) < e.need[k]:
					ok = false
			if ok:
				opts.append({evo = e})
				break
	var pool: Array = Data.UPS.filter(func(u): return p.up.get(u.id, 0) < u.max)
	var mats: Array = pool.filter(func(u):
		for e in Data.EVOS:
			if _evo_live(e) and e.need.get(u.id, 0) > p.up.get(u.id, 0):
				return true
		return false)
	if mats.size() and opts.size() < 3:
		var u = mats[randi() % mats.size()]
		opts.append({up = u, mat = true})
		pool.erase(u)
	while opts.size() < 3 and pool.size():
		var u = pool.pop_at(randi() % pool.size())
		var mat = false
		for e in Data.EVOS:
			if _evo_live(e) and e.need.get(u.id, 0) > p.up.get(u.id, 0):
				mat = true
		opts.append({up = u, mat = mat})
	if opts.is_empty():
		opts.append({heal = true})
	leveled.emit(opts)


func choose_upgrade(o: Dictionary) -> void:
	if o.has("evo"):
		p.evo[o.evo.id] = true
		_evolve_fx(o.evo)
		if o.evo.id == "lmg":
			p.reload = 0.0
			p.ammo = 1
		if o.evo.id == "comms":
			_spawn_comms()
		if o.evo.id == p.w.id:
			p.ammo = mag_size()
			p.reload = 0.0
	elif o.has("heal"):
		p.hp = minf(p.maxhp, p.hp + 40)
	else:
		p.up[o.up.id] = p.up.get(o.up.id, 0) + 1
		if o.up.id == "hp":
			p.hp = minf(p.maxhp + 20, p.hp + 20)
	recalc()
	pause = ""


## 진화 순간: 슬로모션 + 줌인 + 충격파 + 원형 연쇄 폭발 + 팡파르
func _evolve_fx(ev: Dictionary) -> void:
	evo_col = Color(EVO_COL.get(ev.id, "#f2c21b"))
	evo_name = ev.n
	evoT = 2.0
	flash = 0.3
	shake = 24.0
	p.inv = maxf(p.inv, 2.5)
	_vib(120)
	explode(p.x, p.y, 280, 420, {noFF = true, fixed = true, kb = 650.0, c = evo_col})
	fx.append({x = p.x, y = p.y, r = 200.0, t = 0.0, d = 0.6})
	var cx: float = p.x
	var cy: float = p.y
	for i in 12:
		var a = i * TAU / 12
		later(0.12 + i * 0.045, func():
			explode(cx + cos(a) * 200, cy + sin(a) * 200, 70, 180, {noFF = true, fixed = true, small = true})
			fx.append({x = cx + cos(a) * 200, y = cy + sin(a) * 200, r = 60.0, t = 0.0, d = 0.35, c = evo_col}))
	for i in 40:
		if pt.size() >= 400:
			break
		var a = randf() * TAU
		var s = 160.0 + randf() * 260
		pt.append({x = p.x, y = p.y, vx = cos(a) * s, vy = sin(a) * s, t = 0.0, d = 0.7 + randf() * 0.5, c = evo_col, r = 3.0, g = 0.0, h = 0.8, rise = 3.0, glow = true})
	## 팡파르: 상승 아르페지오 + 저음 붐
	Synth.noise(1.0, 0.3, 300)
	Synth.beep(70, 0.9, "sawtooth", 0.08, -30)
	var notes = [392.0, 523.0, 659.0, 784.0, 1047.0]
	for i in notes.size():
		Synth.beep(notes[i], 0.5 if i == notes.size() - 1 else 0.14, "square", 0.05, 0.0, 0.1 + i * 0.09)
	Synth.beep(1568, 0.6, "sine", 0.04, 0.0, 0.55)
	_evo_glow()


## 진화 무기 명중: 색 불꽃, 처치 시 터지는 연출
var _evo_snd := 0.0
func _evo_hit(b: Dictionary, e: Dictionary) -> void:
	var wc = wcol()
	for j in 3:
		if pt.size() < 400:
			var a = randf() * TAU
			pt.append({x = b.x, y = b.y, vx = cos(a) * 110 + b.vx * 0.15, vy = sin(a) * 110 + b.vy * 0.15, t = 0.0, d = 0.25, c = wc, r = 2.0, g = 0.0, h = LIFT, glow = true})
	if e.hp > 0:
		return
	## 처치: 색 충격링 + 파편 + 화면 흔들림 + 날아가는 시체 대신 터지는 파편
	fx.append({x = e.x, y = e.y, r = 34.0 + e.r, t = 0.0, d = 0.28, c = wc})
	puff(e.x, e.y, wc, 8, 220)
	puff(e.x, e.y, Color("#5a1a14"), 5, 140)
	shake = minf(14.0, shake + 2.0)
	if t - _evo_snd > 0.06:
		_evo_snd = t
		Synth.beep(220, 0.1, "square", 0.04, -140)
		Synth.noise(0.12, 0.08, 1400)


## ---------- 통신 드론 ----------
func _spawn_comms() -> void:
	var n = AC.quad("#62d0f0", "#2a3a4a")
	ML.cyl(n, 0.02, 0.02, 0.5, "#c8d3e2", Vector3(0, 0.45, 0), Vector3.ZERO, 6)
	var dish = ML.cyl(n, 0.22, 0.05, 0.1, "#dfe7ef", Vector3(0, 0.72, 0), Vector3(0.6, 0, 0), 12)
	dish.name = "Dish"
	ML.sph(n, 0.06, "#62d0f0", Vector3(0, 0.95, 0), Vector3.ONE, ML.mat("#62d0f0", 3.0), 6)
	dyn.add_child(n)
	var cd = {}
	for s in strats:
		cd[s.id] = 3.0
	comms = {node = n, cd = cd, think = 1.0, x = p.x, y = p.y, flash = 0.0}


func comms_max(s: Dictionary) -> float:
	return s.cd * p.m.cd


func _update_comms(dt: float) -> void:
	if comms == null:
		return
	## 플레이어 어깨 뒤를 따라다닌다
	var tx = p.x - p.fx * 26 + p.fy * 22
	var ty = p.y - p.fy * 26 - p.fx * 22
	comms.x = lerpf(comms.x, tx, minf(1.0, dt * 4))
	comms.y = lerpf(comms.y, ty, minf(1.0, dt * 4))
	comms.flash -= dt
	for id in comms.cd:
		comms.cd[id] = maxf(0.0, comms.cd[id] - dt)
	comms.think -= dt
	if comms.think > 0 or over or in_aa() or ext.state == "land" or aim != null:
		return
	comms.think = 0.8
	var combat: bool = alertN > 0
	var hpk: float = p.hp / p.maxhp
	for s in strats:
		if comms.cd.get(s.id, 0.0) > 0:
			continue
		var ok = false
		match s.id:
			"supply": ok = hpk < 0.5
			"heal": ok = hpk < 0.6 and combat
			"shield": ok = hpk < 0.35 and combat
			"moab": ok = false
			"drone", "missiles", "turret", "mortar": ok = combat
			_: ok = combat and pick_from(p.x, p.y, 330, 95) != null
		if not ok:
			continue
		comms.cd[s.id] = comms_max(s)
		comms.flash = 0.5
		floater(comms.x, comms.y, "통신 드론 ▸ " + s.name, Color("#62d0f0"), 15)
		fx.append({x = comms.x, y = comms.y, r = 26.0, t = 0.0, d = 0.35, c = Color("#62d0f0")})
		## 드론이 실제로 모스 부호를 송신하는 소리
		var dl = 0.0
		for ch in s.code:
			Synth.beep(1250, 0.04 if ch == "." else 0.11, "sine", 0.035, 0.0, dl)
			dl += 0.07 if ch == "." else 0.15
		exec(s, auto_target(s))
		return


func wcol() -> Color:
	return Color(EVO_COL.get(p.w.id, "#f2c21b"))


## 진화한 주무기에 발광 부품을 붙인다
func _evo_glow() -> void:
	if player_node == null or not p.evo.has(p.w.id):
		return
	var gun = player_node.get_node_or_null("Body/Gun")
	if gun == null or gun.has_node("EvoGlow"):
		return
	var g = Node3D.new()
	g.name = "EvoGlow"
	gun.add_child(g)
	var c = wcol()
	ML.no_shadow(ML.box(g, Vector3(0.62, 0.035, 0.075), c, Vector3(0.3, 0.055, 0), Vector3.ZERO, ML.mat(c, 3.0, 1.0, true)))
	ML.no_shadow(ML.box(g, Vector3(0.62, 0.035, 0.075), c, Vector3(0.3, -0.055, 0), Vector3.ZERO, ML.mat(c, 3.0, 1.0, true)))
	ML.no_shadow(ML.sph(g, 0.07, c, Vector3(0.78, 0, 0), Vector3.ONE, ML.mat(c, 4.0, 1.0, true), 8))
	var l = OmniLight3D.new()
	l.light_color = c
	l.omni_range = 2.6
	l.light_energy = 1.2
	l.position = Vector3(0.4, 0.1, 0)
	g.add_child(l)


func gold_now() -> int:
	return int(kills * 0.12) + map.objs.filter(func(o): return o.done).size() * 40 + bonus + silent * 2


func end_game(win: bool) -> void:
	if over:
		return
	over = true
	run = false
	aim = null
	release_key(true)
	var st = (3 if p.lives >= 2 else 2 if p.lives == 1 else 1) if win else 0
	var done: int = map.objs.filter(func(o): return o.done).size()
	var rows = [["처치 %d" % kills, int(kills * 0.12)], ["은밀 처치 %d" % silent, silent * 2], ["목표 %d / %d" % [done, map.objs.size()], done * 40], ["연속 처치 보너스 (최고 %d)" % best, bonus]]
	if win:
		rows.append(["탈출 성공", 120])
		rows.append(["별 %d개" % st, st * 30])
	var total = 0
	for r in rows:
		total += r[1]
	if diff > 0:
		var db = int(total * 0.5 * diff)
		rows.append(["위험도 보너스 x%.1f" % (1.0 + 0.5 * diff), db])
		total += db
	Save.d.gold += total
	Save.d.runs += 1
	Save.persist()
	if win:
		Synth.beep(523, 0.15)
		later(0.16, func(): Synth.beep(784, 0.4))
	else:
		Synth.beep(200, 0.6, "sawtooth", 0.07, -150)
	await get_tree().create_timer(0.9 if win else 0.5).timeout
	ended.emit(win, rows, total, st)


## ---------- 모스 입력 ----------
func codes() -> Array:
	var a: Array = []
	for s in strats:
		a.append({code = s.code, s = s})
	var c = ctx_code()
	if c != null:
		a.append(c)
	return a


func ctx_code():
	if not active:
		return null
	for o in map.objs:
		if o.type == "term" and not o.done and d2(o, p) < o.r:
			return {code = o.code, name = "단말기 해킹", o = o}
	if ext.state == "call" and d2(ext, p) < ext.r:
		return {code = Data.SOS, name = "수송 헬기 호출 SOS", ext = true}
	return null


func press_key() -> void:
	if not active or not run or pause != "" or M.down:
		return
	if aim != null:
		aim = null
		floater(p.x, p.y, "호출 취소", Color("#9fb0d9"))
		Synth.beep(200, 0.1)
		return
	## 다음에 올 수 있는 기호가 하나뿐이면 그쪽으로 판정 기준을 당겨 준다
	var dot = false
	var dash = false
	var b: String = M.buf
	for a in codes():
		if a.code.length() > b.length() and a.code.begins_with(b):
			if a.code[b.length()] == ".":
				dot = true
			else:
				dash = true
	M.thr = 0.15 if dot and dash else 0.095 if dash else 0.215 if dot else 0.15
	M.down = true
	M.fired = false
	M.t0 = Time.get_ticks_msec() / 1000.0
	M.pid += 1
	var pid: int = M.pid
	Synth.tone(true)
	_vib(8)
	get_tree().create_timer(M.thr).timeout.connect(func():
		if M.down and M.pid == pid and not M.fired:
			M.fired = true
			_vib(18)
			push_sym("-"))


func release_key(cancel: bool) -> void:
	if not M.down:
		return
	M.down = false
	Synth.tone(false)
	if cancel or M.fired or not active or not run or pause != "":
		return
	push_sym("." if Time.get_ticks_msec() / 1000.0 - M.t0 < M.thr else "-")


func key_progress() -> float:
	if not M.down:
		return 0.0
	return clampf((Time.get_ticks_msec() / 1000.0 - M.t0) / M.thr, 0.0, 1.0)


func fire_code(hit: Dictionary) -> void:
	if hit.has("s"):
		var s: Dictionary = hit.s
		if s.t > 1.2:
			morse_err("재충전 중")
		elif s.t > 0:
			M.queue = s
			floater(p.x, p.y, "대기 중…", Color("#f2c21b"))
		else:
			trigger(s)
	elif hit.has("o"):
		complete_obj(hit.o)
	elif hit.has("ext"):
		ext.state = "wait"
		ext.t = 30.0
		banner("헬기 도착까지 버텨라")
		Synth.beep(520, 0.5, "sawtooth", 0.06, 400)
		heat = maxi(heat, 3)
		spawn("tk")
		spawn("tk")
		make_noise(p.x, p.y, 900)


func cancel_morse() -> void:
	if not active or not run or pause != "":
		return
	var any: bool = M.buf != "" or M.pend != null or M.queue != null
	if aim != null:
		aim = null
		any = true
		floater(p.x, p.y, "호출 취소", Color("#9fb0d9"))
	release_key(true)
	M.buf = ""; M.miss = 0; M.pend = null; M.queue = null
	if any:
		Synth.beep(200, 0.1)
		_vib(10)


## 부호가 겹칠 때(짧은 부호가 긴 부호의 앞부분일 때): 짧은 부호를 바로 쓰지 않고 PEND초 동안 다음 입력을 기다린다
func push_sym(s: String) -> void:
	M.pend = null
	var all = codes()
	var nb: String = M.buf + s
	var hit = null
	var longer = false
	var prefix = false
	for a in all:
		if a.code == nb:
			hit = a
		if a.code.length() > nb.length() and a.code.begins_with(nb):
			longer = true
		if a.code.begins_with(nb):
			prefix = true
	if hit != null and longer:
		M.buf = nb; M.pend = hit; M.pendT = rt; M.last = rt
	elif hit != null:
		M.buf = ""; M.miss = 0
		fire_code(hit)
	elif prefix:
		M.buf = nb
		M.last = rt
	elif M.buf != "" and M.miss == 0:
		## 한 번의 오타는 무시하고 입력을 유지
		M.miss = 1
		M.last = rt
		Synth.beep(180, 0.08, "sawtooth", 0.05)
		_vib(15)
	else:
		M.buf = ""
		M.miss = 0
		morse_err("")


func morse_err(msg: String) -> void:
	Synth.beep(140, 0.2, "sawtooth", 0.07)
	_vib(40)
	if hud:
		hud.morse_error()
	if msg != "":
		floater(p.x, p.y, msg, Color("#ff8a7a"))


func trigger(s: Dictionary) -> void:
	if in_aa():
		morse_err("방공포 교란: 지원요청 불가")
		return
	Synth.beep(880, 0.12, "square", 0.06)
	Synth.beep(1320, 0.18, "square", 0.06)
	_vib(30)
	if Save.d.aim == "manual" and s.aim != "":
		aim = {s = s, has = false, rt = 6.0, x = 0.0, y = 0.0, sx = 0.0, sy = 0.0}
	else:
		s.t = s.cd * p.m.cd
		exec(s, auto_target(s))


func aim_range(s: Dictionary) -> float:
	return (220.0 if s.id == "mines" else 170.0) if s.aim == "near" else 370.0


func aim_target() -> Dictionary:
	var s: Dictionary = aim.s
	var rng = aim_range(s)
	var cl = func(x: float, y: float) -> Vector2:
		var v = Vector2(x - p.x, y - p.y)
		return Vector2(p.x, p.y) + v.normalized() * rng if v.length() > rng else Vector2(x, y)
	if s.aim == "line":
		var st: Vector2 = cl.call(aim.sx, aim.sy)
		var dv = Vector2(aim.x - aim.sx, aim.y - aim.sy)
		var ang = dv.angle() if dv.length() > 10 else atan2(st.y - p.y, st.x - p.x)
		return {x = st.x, y = st.y, ang = ang}
	var c: Vector2 = cl.call(aim.x, aim.y)
	return {x = c.x, y = c.y, ang = 0.0}


func confirm_aim() -> void:
	var s: Dictionary = aim.s
	var tg = aim_target()
	aim = null
	s.t = s.cd * p.m.cd
	exec(s, tg)


func _vib(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## ---------- 입력: 조이스틱·수동 조준 ----------
func screen_to_ground(pos: Vector2) -> Vector2:
	var o = cam.project_ray_origin(pos)
	var d = cam.project_ray_normal(pos)
	if absf(d.y) < 1e-4:
		return Vector2(p.x, p.y)
	var k = -o.y / d.y
	var hit = o + d * k
	return Vector2(hit.x / K, hit.z / K)


func _input(ev: InputEvent) -> void:
	if not active or not run:
		return
	if ev is InputEventKey and not ev.echo:
		if ev.physical_keycode == KEY_SPACE:
			if ev.pressed:
				press_key()
			else:
				release_key(false)
			get_viewport().set_input_as_handled()
		elif ev.pressed and (ev.physical_keycode == KEY_ESCAPE or ev.physical_keycode == KEY_BACKSPACE):
			cancel_morse()
		return
	if pause != "":
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if hud and hud.blocks(ev.position):
				return
			if aim != null:
				if aim_touch != -1:
					return
				var w = screen_to_ground(ev.position)
				aim_touch = ev.index
				aim.has = true
				aim.sx = w.x; aim.x = w.x; aim.sy = w.y; aim.y = w.y
				return
			if joy.id != -1:
				return
			joy.id = ev.index
			joy.ox = ev.position.x; joy.x = ev.position.x
			joy.oy = ev.position.y; joy.y = ev.position.y
		else:
			if ev.index == aim_touch:
				aim_touch = -1
				if aim != null:
					confirm_aim()
			elif ev.index == joy.id:
				joy.id = -1
	elif ev is InputEventScreenDrag:
		if ev.index == aim_touch and aim != null:
			var w = screen_to_ground(ev.position)
			aim.x = w.x
			aim.y = w.y
		elif ev.index == joy.id:
			joy.x = ev.position.x
			joy.y = ev.position.y
			var dv = Vector2(joy.x - joy.ox, joy.y - joy.oy)
			var r = 90.0
			if dv.length() > r:
				joy.ox = joy.x - dv.x / dv.length() * r
				joy.oy = joy.y - dv.y / dv.length() * r


func move_vec() -> Vector2:
	var v = Vector2.ZERO
	if joy.id != -1:
		v = Vector2(joy.x - joy.ox, joy.y - joy.oy) / 80.0
	else:
		v.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		v.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var d = v.length()
	if d > 1:
		v /= d
	return Vector2.ZERO if d < 0.12 else v


## ---------- 프레임 ----------
func _process(raw_dt: float) -> void:
	var raw = minf(0.05, raw_dt)
	if preview_mode:
		lobT += raw
		_preview_cam()
		return
	if not active:
		return
	if run and pause == "":
		rt += raw
		var sc = 0.18 if aim != null else 1.0
		if hs > 0:
			hs -= raw
			sc = 0.04
		if evoT > 0:
			## 진화: 처음 1.2초는 거의 정지에 가까운 슬로모션, 이후 원래 속도로 복귀
			evoT -= raw
			sc = minf(sc, 0.22 if evoT > 0.8 else lerpf(1.0, 0.22, evoT / 0.8))
		if flash > 0:
			flash -= raw
		if aim != null:
			aim.rt -= raw
			if aim.rt <= 0:
				var s: Dictionary = aim.s
				aim = null
				s.t = s.cd * p.m.cd
				exec(s, auto_target(s))
		if M.pend != null and not M.down and rt - M.pendT > PEND:
			var h: Dictionary = M.pend
			M.pend = null
			M.buf = ""
			M.miss = 0
			fire_code(h)
		if M.buf != "" and not M.down and rt - M.last > 2.2:
			M.buf = ""
			M.miss = 0
			M.pend = null
		update(raw * sc)
	_sync(raw)


func update(dt: float) -> void:
	t += dt
	for i in range(timers.size() - 1, -1, -1):
		var tm: Dictionary = timers[i]
		tm.t -= dt
		if tm.t <= 0:
			timers.remove_at(i)
			tm.fn.call()
	for s in strats:
		if s.t > 0:
			s.t -= dt
	if M.queue != null and M.queue.t <= 0:
		var s: Dictionary = M.queue
		M.queue = null
		if aim == null:
			trigger(s)
	if comboT > 0:
		comboT -= dt
		if comboT <= 0:
			combo = 0
	## 플레이어
	var mv = Vector2.ZERO if (aim != null and aim_touch != -1 and joy.id == -1) else move_vec()
	var sp: float = 128.0 * p.m.spd
	if mv != Vector2.ZERO:
		p.x += mv.x * sp * dt
		p.y += mv.y * sp * dt
		var d = mv.length()
		p.fx = mv.x / d
		p.fy = mv.y / d
		p.face = mv.angle()
		p.mv = true
	else:
		p.mv = false
	p.x = clampf(p.x, 15, WORLD - 15)
	p.y = clampf(p.y, 15, WORLD - 15)
	rock_push(p)
	p.shieldT -= dt; p.boostT -= dt; p.inv -= dt; p.hurtT -= dt
	## 주무기: 사거리 안 가장 가까운 적을 자동 조준해서 쏜다. 적이 없으면 이동 방향을 본다
	var w: Dictionary = p.w
	var ev: Dictionary = p.evo
	if p.reload > 0:
		p.reload -= dt
		if p.reload <= 0:
			p.ammo = mag_size()
	else:
		p.fireT -= dt
		var tg = null
		tg = nearest(p.x, p.y, w.range, true, true, dbg_trace, true)
		p.aim = atan2(tg.y - p.y, tg.x - p.x) if tg != null else turn_to(p.aim, p.face, dt * 14)
		if tg != null:
			if p.fireT <= 0:
				p.fireT = 1.0 / (w.rate * p.m.rate * (1.5 if p.boostT > 0 else 1.0) * (1.5 if ev.has("lmg") else 1.0))
				var n: int = w.pellets + p.m.multi + (4 if ev.has("sg") else 0)
				var sprd: float = 0.1 if ev.has("lmg") else w.spread
				var ex = {}
				if ev.has("ar"): ex = {rico = 2}
				elif ev.has("sg"): ex = {fire = true}
				elif ev.has("rail"): ex = {boom = true}
				var evw: bool = ev.has(w.id)
				if evw:
					ex.evo = true
				for i in n:
					var a: float = p.aim + ((randf() - 0.5) * sprd if w.pellets > 1 else (i - (n - 1) / 2.0) * 0.11 + (randf() - 0.5) * sprd)
					shoot(p.x + cos(p.aim) * 14, p.y + sin(p.aim) * 14, a, w, w.dmg * p.m.dmg, 99 if ev.has("rail") else w.pierce + p.m.pierce, ex)
				p.muz = 0.05
				if evw:
					## 진화 무기: 반동 흔들림, 총구 섬광 입자, 묵직한 저음
					var wc = wcol()
					shake = maxf(shake, 7.0 if w.id == "rail" else 5.0 if w.id == "sg" else 2.2)
					var mx = p.x + cos(p.aim) * 22
					var my = p.y + sin(p.aim) * 22
					for j in (6 if w.id == "rail" or w.id == "sg" else 2):
						if pt.size() < 400:
							var sa = p.aim + (randf() - 0.5) * 0.9
							var ss = 120.0 + randf() * 160
							pt.append({x = mx, y = my, vx = cos(sa) * ss, vy = sin(sa) * ss, t = 0.0, d = 0.18, c = wc, r = 2.5, g = 0.0, h = LIFT, glow = true})
					if w.id == "rail":
						beams.append({x0 = mx, y0 = my, x1 = p.x + cos(p.aim) * w.range, y1 = p.y + sin(p.aim) * w.range, t = 0.0, d = 0.35, w = 0.9, c = wc})
					if t - last_shot > 0.07:
						Synth.beep(110 if w.id != "rail" else 80, 0.12, "sawtooth", 0.05, -50)
				if not ev.has("lmg"):
					p.ammo -= 1
					if p.ammo <= 0:
						p.reload = w.reload * p.m.rl
				make_noise(p.x, p.y, w.noise, p)
				if t - last_shot > 0.07:
					last_shot = t
					Synth.noise(0.06, 0.12 if w.id == "rail" else 0.05, 900 if w.id == "sg" else 2200)
		elif p.fireT < 0:
			p.fireT = 0.0
	p.muz -= dt
	## 보조무기
	var gl: int = p.up.get("gren", 0)
	var tl: int = p.up.get("taser", 0)
	if gl:
		p.grenT -= dt
		if p.grenT <= 0:
			var tg2 = pick_from(p.x, p.y, 260, 40)
			if tg2 != null:
				p.grenT = 3.2 - 0.3 * gl
				var dmg = 50.0 + 18 * gl
				var cl: bool = ev.has("gren")
				_lob(p.x, p.y, tg2.x, tg2.y, 0.45, func():
					explode(tg2.x, tg2.y, 55, dmg, {noFF = true})
					if cl:
						for i in 4:
							var a = i * TAU / 4 + 0.6
							later(0.18, func(): explode(tg2.x + cos(a) * 48, tg2.y + sin(a) * 48, 40, dmg * 0.6, {noFF = true, small = true})))
			else:
				p.grenT = 0.3
	if tl:
		p.tasT -= dt
		if p.tasT <= 0:
			p.tasT = 2.4
			var rg = 190.0 if ev.has("taser") else 140.0
			var mx: int = 16 if ev.has("taser") else 2 + tl
			var c: Array = en.filter(func(e): return e.hp > 0 and Vector2(e.x - p.x, e.y - p.y).length() < rg)
			c.sort_custom(func(a, b): return d2(a, p) < d2(b, p))
			c = c.slice(0, mx)
			for e in c:
				hit_enemy(e, 28 + 10 * tl, true)
				if ev.has("taser"):
					e.frz = maxf(e.frz, 0.6)
				arcs.append({x1 = p.x, y1 = p.y, x2 = e.x, y2 = e.y, t = 0.14})
			if c.size():
				Synth.beep(1800, 0.08, "sawtooth", 0.03, -900)
	## 격자
	for cell in grid:
		cell.clear()
	for e in en:
		e.x = clampf(e.x, 5, WORLD - 5)
		e.y = clampf(e.y, 5, WORLD - 5)
		grid[int(e.y / TS) * TN + int(e.x / TS)].append(e)
	## 열압력탄 소용돌이
	for v in vort:
		v.t -= dt
		for e in en:
			var dx: float = v.x - e.x
			var dy: float = v.y - e.y
			var d = maxf(1.0, sqrt(dx * dx + dy * dy))
			if d < v.r:
				var s = (40.0 if e.type == "tk" else 170.0) * dt
				e.x += dx / d * minf(s, d)
				e.y += dy / d * minf(s, d)
				hit_enemy(e, 40 * dt, true)
	vort = vort.filter(func(v): return v.t > 0)
	_update_enemies(dt)
	for i in range(tele.size() - 1, -1, -1):
		var tl2: Dictionary = tele[i]
		tl2.t -= dt
		if tl2.t <= 0:
			tele.remove_at(i)
			enemy_blast(tl2.x, tl2.y, tl2.r, tl2.d)
	_update_bullets(dt)
	_update_effects(dt)
	## 사망 처리
	for i in range(en.size() - 1, -1, -1):
		if en[i].hp <= 0:
			kill_enemy(en[i])
			en.remove_at(i)
	## 아이템
	for i in range(gems.size() - 1, -1, -1):
		var g: Dictionary = gems[i]
		var dv = Vector2(p.x - g.x, p.y - g.y)
		var d = maxf(1.0, dv.length())
		if d < p.m.magnet or g.pull:
			g.pull = true
			g.x += dv.x / d * 340 * dt
			g.y += dv.y / d * 340 * dt
		if d < 14:
			gems.remove_at(i)
			if g.lv:
				gain_xp(p.next - p.xp)
				floater(p.x, p.y, "즉시 진급", Color("#f2c21b"), 17)
			else:
				gain_xp(g.v)
			if t - last_shot > 0.03:
				Synth.beep(900 + randf() * 200, 0.04, "sine", 0.025)
	for i in range(crates.size() - 1, -1, -1):
		var c: Dictionary = crates[i]
		if Vector2(c.x - p.x, c.y - p.y).length() < 24:
			crates.remove_at(i)
			c.node.queue_free()
			p.hp = minf(p.maxhp, p.hp + p.maxhp * 0.45)
			p.boostT = 8.0
			p.ammo = mag_size()
			p.reload = 0.0
			floater(p.x, p.y, "보급 완료", Color("#a6dc68"))
			Synth.beep(600, 0.1); Synth.beep(900, 0.2)
	if p.xp >= p.next:
		gain_xp(0)
	## 목표
	for o in map.objs:
		if o.done:
			continue
		var d = d2(o, p)
		if o.type == "cap":
			if d < o.r:
				o.prog += dt / 16.0
				## 점령 개시: 은신과 무관하게 적이 무조건 증원을 보낸다
				if not o.get("siege", false):
					o.siege = true
					o.wT = 2.0
					banner("통신탑 점령 개시! 적 증원 접근 중")
					Synth.beep(240, 0.4, "sawtooth", 0.06, -80)
					for f in en:
						if Vector2(f.x - o.x, f.y - o.y).length() < 450:
							alert_e(f, true)
			## 점령 게이지는 구역을 벗어나도 줄지 않는다. 증원은 탑 근처(700)에 있는 동안만 온다
			if o.get("siege", false) and d < 700:
				o.wT -= dt
				if o.wT <= 0:
					o.wT = 7.0
					_siege_wave()
			if o.prog >= 1:
				complete_obj(o)
		elif is_dest(o):
			if o.type == "nest" and d < 520 and alertN > 0:
				o.spT -= dt
				if o.spT <= 0 and en.size() < 300:
					o.spT = 2.2
					var a = randf() * TAU
					spawn("ru", o.x + cos(a) * 40, o.y + sin(a) * 40)
			if o.hp <= 0:
				complete_obj(o)
				hs = 0.1
				explode(o.x, o.y, 100, 300, {noFF = true, fixed = true})
		if not o.known and d < 420:
			o.known = true
			banner(("방공포" if o.type == "aa" else "적 부대" if o.type == "nest" else "목표") + " 발견")
	## 탈출
	if ext.state == "wait":
		ext.t -= dt
		if ext.t <= 0:
			ext.state = "land"
			ext.ship = 0.0
			banner("헬기 도착. 탑승하라")
			heli_node = AC.heli()
			dyn.add_child(heli_node)
			later(1.2, func(): explode(ext.x, ext.y, 100, 500, {noFF = true, fixed = true, kb = 500.0}))
	elif ext.state == "land":
		ext.ship = minf(1.0, ext.ship + dt / 1.2)
		if ext.ship >= 1 and d2(ext, p) < ext.r * 0.7:
			end_game(true)
	## 스폰: 평소에는 맵에 배치된 적만 있다. 탈출 대기 중에만 계속 몰려온다
	if ext.state == "wait" or ext.state == "land":
		spawnT -= dt
		if spawnT <= 0:
			spawnT = 1.0
			var n = minf(9.0, 2.4 + t / 90.0) * reinf_mul
			var ni = int(n) + (1 if randf() < fmod(n, 1.0) else 0)
			for i in ni:
				if en.size() >= 300:
					break
				var r = randf()
				spawn("tk" if r < 0.04 else "dr" if r < 0.14 else "rf" if r < 0.36 else "sh" if r < 0.5 else "ru")
	rcd -= dt
	if rcall != null and (rcall.hp <= 0 or rcall.st != "call"):
		rcall = null
	## 연출
	for f in fx:
		f.t += dt
	fx = fx.filter(func(f): return f.t < f.d)
	for i in range(jets.size() - 1, -1, -1):
		var j: Dictionary = jets[i]
		j.x += j.vx * dt
		j.y += j.vy * dt
		j.life -= dt
		if j.life <= 0:
			j.node.queue_free()
			jets.remove_at(i)
	for i in range(bombs.size() - 1, -1, -1):
		var b: Dictionary = bombs[i]
		b.t += dt
		if b.t >= b.d:
			b.node.queue_free()
			bombs.remove_at(i)
	_update_comms(dt)
	for bm in beams:
		bm.t += dt
	beams = beams.filter(func(bm): return bm.t < bm.d)
	for i in range(fl.size() - 1, -1, -1):
		var f: Dictionary = fl[i]
		f.t += dt
		if f.t >= 1.0:
			f.lb.visible = false
			fl.remove_at(i)
	for q in pt:
		q.t += dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		q.vx *= 0.92
		q.vy *= 0.92
	pt = pt.filter(func(q): return q.t < q.d)
	shake = maxf(0.0, shake - dt * 34)


func _lob(x0: float, y0: float, x1: float, y1: float, d: float, fn: Callable) -> void:
	var n = Node3D.new()
	ML.sph(n, 0.12, "#3f4636", Vector3.ZERO, Vector3.ONE, null, 6)
	dyn.add_child(n)
	lobs.append({x0 = x0, y0 = y0, x1 = x1, y1 = y1, t = 0.0, d = d, fn = fn, node = n})


func _update_enemies(dt: float) -> void:
	alertN = 0
	susN = 0
	for e in en:
		if e.burn > 0:
			e.burn -= dt
			e.hp -= 20 * p.m.dmg * dt
		e.flash -= dt
		e.alT -= dt
		if e.st == "alert" or e.st == "call":
			alertN += 1
		elif e.st == "sus":
			susN += 1
		if e.frz > 0:
			e.frz -= dt
			e.x += e.vx * dt
			e.y += e.vy * dt
			e.vx *= 1 - minf(1, dt * 6)
			e.vy *= 1 - minf(1, dt * 6)
			continue
		var dx: float = p.x - e.x
		var dy: float = p.y - e.y
		var d = maxf(1.0, sqrt(dx * dx + dy * dy))
		var s: float = e.T.spd
		var tx = 0.0
		var ty = 0.0
		var sp = 0.0
		e.chk -= dt
		if e.chk <= 0:
			e.chk = 0.12 + randf() * 0.08
			e.sv = see_p(e, d, dx, dy) if d < e.T.vis + 20 else 0.0
		if e.st == "alert":
			if e.sv > 0:
				e.seen = 0.0
				last_seen = Vector2(p.x, p.y)
			else:
				e.seen += dt
				if e.seen > 7:
					e.st = "sus"
					e.inv = last_seen if last_seen != null else Vector2(p.x, p.y)
					e.aw = 0.6
					e.lookT = 0.0
			e.face = atan2(dy, dx)
			tx = dx / d
			ty = dy / d
			sp = s
			if e.T.get("ranged", false):
				if d < 150:
					sp = -s * 0.6
				elif d < 190:
					sp = 0.0
				e.shoot -= dt
				if e.shoot <= 0 and d < 260 and e.sv > 0:
					e.shoot = 2.3
					eb.append({x = e.x, y = e.y, vx = dx / d * 150, vy = dy / d * 150, life = 2.2, dmg = e.T.dmg})
			if e.type == "tk":
				e.ha = turn_to(e.get("ha", e.face), e.face, dt * 1.4)
				e.shoot -= dt
				if e.shoot <= 0 and d < 340 and e.sv > 0:
					e.shoot = 4.0
					tele.append({x = p.x + p.fx * 20, y = p.y + p.fy * 20, r = 52.0, t = 1.1, max = 1.1, d = 20.0})
		elif e.st == "call":
			e.face = atan2(dy, dx)
			e.callT -= dt
			if e.callT <= 0:
				e.st = "alert"
				reinforce(e)
		else:
			if e.sv > 0:
				e.aw += dt * (0.55 + e.sv * 2.4) * (1.0 if p.mv else 0.6)
				e.inv = Vector2(p.x, p.y)
				e.lookT = 0.0
				if e.aw > 0.3 and e.st != "sus":
					e.st = "sus"
				if e.aw >= 1:
					alert_e(e)
			else:
				e.aw = maxf(0.0, e.aw - dt * 0.2)
			if e.st == "sus":
				var q: Vector2 = e.inv - Vector2(e.x, e.y)
				var qd = q.length()
				if qd > 16 and not (e.get("lookT", 0.0) > 0):
					tx = q.x / qd
					ty = q.y / qd
					sp = s * 0.6
					e.face = turn_to(e.face, q.angle(), dt * 6)
				else:
					e.lookT = e.get("lookT", 0.0) + dt
					e.face += dt * 1.7 * sin(e.lookT * 1.3 + e.ph)
					if e.lookT > 4.5 and e.aw < 0.3:
						e.st = e.home
						e.lookT = 0.0
			elif e.st == "patrol":
				var gx: float
				var gy: float
				var L = e.lead
				if L != null and L.hp > 0 and L.st == "patrol":
					gx = L.x - cos(L.face) * 22 * e.slot
					gy = L.y - sin(L.face) * 22 * e.slot
				else:
					var wp: Vector2 = e.rt[e.ri]
					gx = wp.x
					gy = wp.y
					if Vector2(gx - e.x, gy - e.y).length() < 16:
						e.ri = (e.ri + 1) % e.rt.size()
				var q = Vector2(gx - e.x, gy - e.y)
				var qd = q.length()
				if qd > 6:
					tx = q.x / qd
					ty = q.y / qd
					sp = s * 0.42 * (0.5 if qd < 20 else 1.0)
					e.face = turn_to(e.face, q.angle(), dt * 4)
			elif e.st == "post":
				var q = Vector2(e.px - e.x, e.py - e.y)
				var qd = q.length()
				if qd > 10:
					tx = q.x / qd
					ty = q.y / qd
					sp = s * 0.4
					e.face = turn_to(e.face, q.angle(), dt * 4)
				else:
					e.face = turn_to(e.face, e.bf + sin(t * 0.45 + e.ph) * 1.1, dt * 2)
			if e.type == "tk":
				e.ha = turn_to(e.get("ha", e.face), e.face, dt * 1.2)
			if d < e.r + p.r + 8:
				alert_e(e)
		e.x += (tx * sp + e.vx) * dt
		e.y += (ty * sp + e.vy) * dt
		e.vx *= 1 - minf(1, dt * 6)
		e.vy *= 1 - minf(1, dt * 6)
		e.walk += dt * absf(sp) * 0.13
		for f in grid[int(clampf(e.y, 0, WORLD - 1) / TS) * TN + int(clampf(e.x, 0, WORLD - 1) / TS)]:
			if is_same(f, e):
				continue
			var ax: float = e.x - f.x
			var ay: float = e.y - f.y
			var q = maxf(0.01, sqrt(ax * ax + ay * ay))
			var mm: float = e.r + f.r
			if q < mm:
				var k: float = (mm - q) / q * 0.6 * (f.r / (e.r + f.r))
				e.x += ax * k
				e.y += ay * k
		if not e.T.get("fly", false):
			rock_push(e)
		e.atk -= dt
		if e.st == "alert" and d < e.r + p.r + 3 and e.atk <= 0:
			if e.type == "dr":
				e.hp = 0.0
				enemy_blast(e.x, e.y, 36, e.T.dmg)
			else:
				e.atk = 0.8
				hurt(e.T.dmg)


func _update_bullets(dt: float) -> void:
	for i in range(bul.size() - 1, -1, -1):
		var b: Dictionary = bul[i]
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.life -= dt
		var dead: bool = b.life <= 0 or b.x < 0 or b.y < 0 or b.x >= WORLD or b.y >= WORLD or blocked(b.x, b.y)
		if not dead:
			var cx = int(b.x / TS)
			var cy = int(b.y / TS)
			var done = false
			for j in range(cy - 1, cy + 2):
				if done:
					break
				for k in range(cx - 1, cx + 2):
					if done or j < 0 or k < 0 or j >= TN or k >= TN:
						continue
					for e in grid[j * TN + k]:
						if e.hp <= 0 or b.hit.has(e.uid):
							continue
						if Vector2(e.x - b.x, e.y - b.y).length() < e.r + 4:
							hit_enemy(e, b.dmg, false, b.ap)
							var q = Vector2(b.vx, b.vy).length()
							var kd = 5.0 if e.type == "tk" else 1.0
							e.vx += b.vx / q * b.kb / kd
							e.vy += b.vy / q * b.kb / kd
							if b.get("fire", false):
								e.burn = 3.0
							if b.get("boom", false):
								explode(e.x, e.y, 42, b.dmg * 0.6, {noFF = true, small = true})
							if pt.size() < 400:
								pt.append({x = b.x, y = b.y, vx = -b.vx * 0.1 + (randf() - 0.5) * 60, vy = -b.vy * 0.1 + (randf() - 0.5) * 60, t = 0.0, d = 0.15, c = Color("#fff3a0"), r = 1.5, g = 0.0, h = LIFT})
							if b.get("evo", false):
								_evo_hit(b, e)
							b.hit.append(e.uid)
							if b.pierce > 0:
								b.pierce -= 1
							elif b.get("rico", 0) > 0:
								var nb = null
								var nd = 140.0
								for f in en:
									if f.hp <= 0 or b.hit.has(f.uid):
										continue
									var dd = Vector2(f.x - b.x, f.y - b.y).length()
									if dd < nd:
										nd = dd
										nb = f
								if nb != null:
									b.rico -= 1
									beams.append({x0 = b.x, y0 = b.y, x1 = nb.x, y1 = nb.y, t = 0.0, d = 0.16, w = 0.35, c = wcol()})
									var a = atan2(nb.y - b.y, nb.x - b.x)
									b.vx = cos(a) * q
									b.vy = sin(a) * q
									b.life = 0.35
								else:
									dead = true
									done = true
									break
							else:
								dead = true
								done = true
								break
			if not dead:
				for o in map.objs:
					if is_dest(o) and not o.done and Vector2(o.x - b.x, o.y - b.y).length() < o.r:
						o.hp -= b.dmg
						dead = true
						break
		if dead:
			bul.remove_at(i)
	for i in range(eb.size() - 1, -1, -1):
		var b: Dictionary = eb[i]
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.life -= dt
		if Vector2(b.x - p.x, b.y - p.y).length() < p.r + 4:
			hurt(b.dmg)
			b.life = 0.0
		if b.life <= 0 or blocked(b.x, b.y):
			eb.remove_at(i)


func _update_effects(dt: float) -> void:
	var ev: Dictionary = p.evo
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		z.life -= dt
		var inz = Vector2(p.x - z.x, p.y - z.y).length() < z.r
		if z.k == "fire":
			area_dmg(z.x, z.y, z.r, z.dps * dt)
			if inz:
				hurt(9 * dt)
			if randf() < dt * 14 and pt.size() < 400:
				var a = randf() * TAU
				var rr = sqrt(randf()) * z.r * 0.8
				pt.append({x = z.x + cos(a) * rr, y = z.y + sin(a) * rr, vx = 0.0, vy = 0.0, t = 0.0, d = 0.5 + randf() * 0.3, c = Color("#ff8a1a"), r = 4.0, g = 3.0, h = 0.3, rise = 2.5, glow = true})
		elif inz:
			p.hp = minf(p.maxhp, p.hp + p.maxhp * 0.07 * dt)
		if z.life <= 0:
			zones.remove_at(i)
	for i in range(marks.size() - 1, -1, -1):
		var l: Dictionary = marks[i]
		l.life -= dt
		l.ft -= dt
		var tg = nearest(l.x, l.y, 500, true)
		if tg != null:
			var dv = Vector2(tg.x - l.x, tg.y - l.y)
			var d = maxf(1.0, dv.length())
			var s = minf(d, 150 * dt)
			l.x += dv.x / d * s
			l.y += dv.y / d * s
		if l.ft <= 0:
			l.ft = 0.2
			var a = randf() * TAU
			var d = randf() * 26
			explode(l.x + cos(a) * d, l.y + sin(a) * d, 36, 95, {small = true, ffCap = 6.0})
			shake = minf(8.0, shake + 2)
			Synth.noise(0.12, 0.1, 900)
		if l.life <= 0:
			marks.remove_at(i)
	for i in range(mines.size() - 1, -1, -1):
		var mn: Dictionary = mines[i]
		mn.arm -= dt
		if mn.arm > 0:
			continue
		var trig = false
		var cx = int(clampf(mn.x, 0, WORLD - 1) / TS)
		var cy = int(clampf(mn.y, 0, WORLD - 1) / TS)
		for j in range(cy - 1, cy + 2):
			for k in range(cx - 1, cx + 2):
				if trig or j < 0 or k < 0 or j >= TN or k >= TN:
					continue
				for e in grid[j * TN + k]:
					if not e.T.get("fly", false) and Vector2(e.x - mn.x, e.y - mn.y).length() < e.r + 12:
						trig = true
						break
		if trig:
			mines.remove_at(i)
			mn.node.queue_free()
			explode(mn.x, mn.y, 62, 150)
	for i in range(turrets.size() - 1, -1, -1):
		var tu: Dictionary = turrets[i]
		tu.life -= dt
		tu.fireT -= dt
		if tu.k == "gun":
			var tg = nearest(tu.x, tu.y, 260, true, true)
			if tg != null:
				tu.aim = atan2(tg.y - tu.y, tg.x - tu.x)
				if tu.fireT <= 0:
					tu.fireT = 0.12
					make_noise(tu.x, tu.y, 260, tu)
					shoot(tu.x, tu.y, tu.aim + (randf() - 0.5) * 0.08, {speed = 560.0, range = 270.0, kb = 15.0}, 13 * p.m.dmg, 0)
		elif tu.fireT <= 0:
			var tg = pick_from(tu.x, tu.y, 320, 50)
			if tg != null:
				tu.fireT = 1.1
				tu.aim = atan2(tg.y - tu.y, tg.x - tu.x)
				_lob(tu.x, tu.y, tg.x, tg.y, 0.7, func(): explode(tg.x, tg.y, 54, 125, {ffCap = 10.0}))
				Synth.noise(0.15, 0.12, 300)
			else:
				tu.fireT = 0.3
		if tu.life <= 0:
			turrets.remove_at(i)
			tu.node.queue_free()
			fx.append({x = tu.x, y = tu.y, r = 26.0, t = 0.0, d = 0.3})
	for i in range(drones.size() - 1, -1, -1):
		var d: Dictionary = drones[i]
		if not d.perm:
			d.life -= dt
			if d.life <= 0:
				d.node.queue_free()
				drones.remove_at(i)
				continue
		d.a += dt * 2.2
		d.x = p.x + cos(d.a) * 34
		d.y = p.y + sin(d.a) * 34
		d.fireT -= dt
		if d.fireT <= 0:
			var tg = nearest(d.x, d.y, 230, true, true)
			if tg != null:
				d.fireT = (0.2 if ev.has("drone") else 0.32) if d.perm else 0.16
				make_noise(d.x, d.y, 140, d)
				shoot(d.x, d.y, atan2(tg.y - d.y, tg.x - d.x), DW, (7 + 2 * p.up.get("drone", 0) if d.perm else 12) * p.m.dmg, 0)
			else:
				d.fireT = 0.1
	for i in range(mis.size() - 1, -1, -1):
		var s: Dictionary = mis[i]
		if s.d > 0:
			s.d -= dt
			s.x = p.x
			s.y = p.y
			continue
		s.life -= dt
		if s.tg == null or s.tg.hp <= 0:
			s.tg = nearest(s.x, s.y, 600, false)
		if s.tg != null:
			s.a += clampf(ang_d(atan2(s.tg.y - s.y, s.tg.x - s.x), s.a), -7 * dt, 7 * dt)
		s.x += cos(s.a) * 330 * dt
		s.y += sin(s.a) * 330 * dt
		if pt.size() < 400:
			pt.append({x = s.x, y = s.y, vx = 0.0, vy = 0.0, t = 0.0, d = 0.3, c = Color("#cfd6e8"), r = 2.5, g = 0.0, h = LIFT})
		if s.life <= 0 or (s.tg != null and Vector2(s.tg.x - s.x, s.tg.y - s.y).length() < s.tg.r + 8):
			mis.remove_at(i)
			s.node.queue_free()
			explode(s.x, s.y, 44, 280, {noFF = true})
	for i in range(lobs.size() - 1, -1, -1):
		var l: Dictionary = lobs[i]
		l.t += dt
		if l.t >= l.d:
			lobs.remove_at(i)
			l.node.queue_free()
			l.fn.call()
	for c in calls:
		c.t -= dt
	for i in range(calls.size() - 1, -1, -1):
		var c: Dictionary = calls[i]
		if c.t <= 0:
			if c.node:
				c.node.queue_free()
			if c.pod:
				c.pod.queue_free()
			calls.remove_at(i)
	for a in arcs:
		a.t -= dt
	arcs = arcs.filter(func(a): return a.t > 0)


## ---------- 3D 동기화 ----------
func _cam_place(target: Vector3, dist: float, pitch_deg: float, yaw := 0.0) -> void:
	var pitch = deg_to_rad(pitch_deg)
	var off = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)


func _preview_cam() -> void:
	if player_node == null:
		return
	var tp = player_node.position
	player_node.rotation.y = -(PI / 2 + 0.45 + sin(lobT * 0.6) * 0.35)
	AC.walk(player_node, 0.0, 0.0)
	_cam_place(tp + Vector3(0, 0.9, 2.2), 9.5, 32.0, sin(lobT * 0.15) * 0.4 + 0.3)
	cam.fov = 40.0
	sun.directional_shadow_max_distance = 40.0
	for im in [overlay_im, tracer_im, bar_im]:
		im.clear_surfaces()
	parts_mm.visible_instance_count = 0
	gems_mm.visible_instance_count = 0
	scorch_mm.visible_instance_count = 0
	for lb in label_pool:
		lb.visible = false
	for l in light_pool:
		l.visible = false
	for f in fx_pool:
		f.visible = false


func _sync(raw: float) -> void:
	var tp = p3(p.x, p.y)
	var sh = Vector3((randf() - 0.5) * shake, 0, (randf() - 0.5) * shake) * K
	var zk = smoothstep(0.0, 1.0, clampf(evoT / 0.9, 0.0, 1.0))
	_cam_place(tp + sh + Vector3(0, 0, 1.6), 25.0 - 11.0 * zk, 56.0 - 10.0 * zk)
	sun.directional_shadow_max_distance = 70.0
	## 플레이어
	if player_node:
		player_node.position = tp
		player_node.rotation.y = -p.aim
		player_node.visible = not (p.inv > 0 and int(t * 12) % 2 == 1)
		AC.walk(player_node, t * 11.0, 1.0 if p.mv else 0.0)
		AC.set_flash(player_node, p.hurtT > 0)
		shield_node.visible = p.shieldT > 0
		muzzle_light.visible = p.muz > 0
		if p.evo.has(p.w.id):
			muzzle_light.light_color = wcol()
			muzzle_light.light_energy = 3.0
			muzzle_light.omni_range = 8.0
	if comms != null:
		var cn: Node3D = comms.node
		cn.position = p3(comms.x, comms.y, 2.6 + sin(t * 3) * 0.12)
		cn.rotation.y = -p.aim
		cn.get_node("Dish").rotation.y = t * (6.0 if comms.flash > 0 else 1.2)
	for j in jets:
		j.node.position = p3(j.x, j.y, j.alt)
		j.node.rotation = Vector3(0.25 * sin(t * 3 + j.x * 0.01), -j.ang, 0)
	for b in bombs:
		var k: float = b.t / b.d
		b.node.position = p3(b.x, b.y, b.alt * (1.0 - k * k) + 0.3)
		b.node.rotation = Vector3(0, 0, 0.3 * (1.0 - k))
	if call_flare != null:
		call_flare.visible = rcall != null
		if rcall != null:
			call_flare.position = p3(rcall.x, rcall.y)
			var k: float = 1.0 - rcall.callT / rcall.callMax
			call_flare.scale = Vector3(1, 0.3 + 0.5 * k, 1) * (1.0 + 0.15 * sin(t * 18))
	var vis_r = 520.0
	var near = func(o): return absf(o.x - p.x) < vis_r and absf(o.y - p.y) < vis_r * 1.4
	## 적
	for e in en:
		var n: Node3D = e.node
		var v: bool = near.call(e)
		n.visible = v
		if not v:
			continue
		var a: float = atan2(p.y - e.y, p.x - e.x) if (e.st == "alert" or e.st == "call") else e.face
		if e.type == "tk":
			n.position = p3(e.x, e.y)
			n.get_node("Hull").rotation.y = -e.get("ha", a)
			n.get_node("Turret").rotation.y = -a
		elif e.type == "dr":
			n.position = p3(e.x, e.y, 1.3 + sin(t * 6 + e.ph) * 0.12)
			n.rotation.y = -a
		else:
			n.position = p3(e.x, e.y)
			n.rotation.y = -a
			AC.walk(n, e.walk, 0.0 if e.frz > 0 else 1.0 if e.walk != e.get("lw", -1.0) else 0.0)
			e.lw = e.walk
		AC.set_flash(n, e.flash > 0)
		var lb: Label3D = e.lb
		if e.st == "call":
			lb.visible = true
			lb.text = "증원 요청 " + str(int((1.0 - e.callT / e.callMax) * 100)) + "%"
			lb.modulate = Color("#ff6a5a")
		elif e.alT > 0:
			lb.visible = true
			lb.text = "!"
			lb.modulate = Color("#ff3a2a")
		elif e.st != "alert" and (e.st == "sus" or e.aw > 0.12):
			lb.visible = true
			lb.text = "?"
			lb.modulate = Color("#ffe27a").lerp(Color("#ff8a2a"), clampf(e.aw, 0, 1))
		elif e.frz > 0:
			lb.visible = true
			lb.text = "✦"
			lb.modulate = Color("#ffe27a")
		else:
			lb.visible = false
	## 구조물
	for o in map.objs:
		var n: Node3D = o.node
		if not o.done:
			var lamp = n.get_node_or_null("Live/Lamp")
			if lamp:
				lamp.visible = int(t * 3) % 2 == 0
			if o.type == "aa":
				n.get_node("Live/Turret").rotation.y = -(t * 0.6 + o.x)
			if o.type == "nest":
				n.get_node("Live/Flag").rotation.y = sin(t * 4) * 0.15
		var lb: Label3D = o.label
		lb.visible = not o.done and o.known
		match o.type:
			"cap": lb.text = "통신탑 점령 %d%%" % roundi(o.prog * 100)
			"nest": lb.text = "적 부대 파괴"
			"aa": lb.text = "방공포 파괴"
			_: lb.text = "★ 단말기: 부호 입력"
		lb.modulate = Color("#f2f0e8")
	## 포탑·드론·지뢰·미사일·투척물
	for tu in turrets:
		var g: Node3D = tu.node.get_node("Gun")
		g.rotation.y = -tu.aim
	for d in drones:
		d.node.position = p3(d.x, d.y, 1.6 + sin(t * 7 + d.a) * 0.1)
		d.node.rotation.y = -(d.a + PI / 2)
	for mn in mines:
		mn.node.get_node("Led").visible = mn.arm > 0 or int(t * 3) % 2 == 0
	for s in mis:
		s.node.visible = s.d <= 0
		s.node.position = p3(s.x, s.y, LIFT + 0.4)
		s.node.rotation.y = -s.a
	for l in lobs:
		var k: float = l.t / l.d
		l.node.position = p3(lerpf(l.x0, l.x1, k), lerpf(l.y0, l.y1, k), 0.6 + sin(k * PI) * 5.0)
	for c in calls:
		if c.node:
			var k: float = c.t / c.max
			c.node.get_node("Beam").visible = int(t * 8) % 2 == 0 or k > 0.3
		if c.pod:
			var k: float = c.t / c.max
			var f = clampf(k / 0.45, 0.0, 1.0)
			c.pod.visible = k < 0.45
			c.pod.position = p3(c.x, c.y, f * 45.0)
	## 탈출 헬기
	if heli_node:
		var k: float = ext.ship
		var alt = (1.0 - k) * 26.0 + 1.6
		heli_node.position = p3(ext.x, ext.y, alt)
		heli_node.get_node("Rotor").rotation.y += raw * 22.0
		heli_node.get_node("TailRotor").rotation.x += raw * 30.0
		heli_node.get_node("Beacon").visible = int(t * 4) % 2 == 0
	_draw_overlay()
	_draw_tracers()
	_draw_bars()
	_draw_particles()
	_draw_fx()
	for f in fl:
		f.lb.position = p3(f.x, f.y, 2.4 + f.t * 1.6)
		f.lb.modulate.a = 1.0 - f.t


## 바닥 표시 (정점 색 삼각형). y=0.05 근처
func _ov_tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	overlay_im.surface_set_color(col)
	overlay_im.surface_add_vertex(a)
	overlay_im.surface_add_vertex(b)
	overlay_im.surface_add_vertex(c)


func _ov_disc(x: float, y: float, r: float, col: Color, seg := 28) -> void:
	var c = p3(x, y, 0.05)
	for i in seg:
		var a0 = i / float(seg) * TAU
		var a1 = (i + 1) / float(seg) * TAU
		_ov_tri(c, p3(x + cos(a0) * r, y + sin(a0) * r, 0.05), p3(x + cos(a1) * r, y + sin(a1) * r, 0.05), col)


func _ov_ring(x: float, y: float, r: float, w: float, col: Color, dash := false, a_from := 0.0, a_len := TAU, seg := 40) -> void:
	var w2 = w / K * 0.5
	for i in seg:
		if dash and i % 2 == 1:
			continue
		var a0 = a_from + i / float(seg) * a_len
		var a1 = a_from + (i + 1) / float(seg) * a_len
		var o0 = p3(x + cos(a0) * (r + w2), y + sin(a0) * (r + w2), 0.06)
		var i0 = p3(x + cos(a0) * (r - w2), y + sin(a0) * (r - w2), 0.06)
		var o1 = p3(x + cos(a1) * (r + w2), y + sin(a1) * (r + w2), 0.06)
		var i1 = p3(x + cos(a1) * (r - w2), y + sin(a1) * (r - w2), 0.06)
		_ov_tri(o0, i0, o1, col)
		_ov_tri(i0, i1, o1, col)


func _ov_fan(x: float, y: float, r: float, a: float, half: float, col: Color, seg := 12) -> void:
	var c = p3(x, y, 0.05)
	for i in seg:
		var a0 = a - half + i / float(seg) * half * 2
		var a1 = a - half + (i + 1) / float(seg) * half * 2
		_ov_tri(c, p3(x + cos(a0) * r, y + sin(a0) * r, 0.05), p3(x + cos(a1) * r, y + sin(a1) * r, 0.05), col)


func _ov_rect(x: float, y: float, ang: float, x0: float, x1: float, hw: float, col: Color) -> void:
	var ca = cos(ang)
	var sa = sin(ang)
	var P = func(u, v): return p3(x + ca * u - sa * v, y + sa * u + ca * v, 0.05)
	_ov_tri(P.call(x0, -hw), P.call(x1, -hw), P.call(x1, hw), col)
	_ov_tri(P.call(x0, -hw), P.call(x1, hw), P.call(x0, hw), col)


func _draw_overlay() -> void:
	overlay_im.clear_surfaces()
	overlay_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_ov_tri(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Color(0, 0, 0, 0))
	var gold = Color("#f2c21b")
	## 방공포 교란 구역
	for o in map.objs:
		if o.type == "aa" and not o.done and d2(o, p) < AAR + 600:
			_ov_disc(o.x, o.y, AAR, Color(1, 0.23, 0.16, 0.05), 48)
			_ov_ring(o.x, o.y, AAR, 0.35, Color(1, 0.23, 0.16, 0.6), true, 0.0, TAU, 64)
	## 탈출 지점
	if ext.state != "locked":
		_ov_disc(ext.x, ext.y, ext.r, Color(0.17, 0.19, 0.21, 0.3))
		_ov_ring(ext.x, ext.y, ext.r, 0.3, gold, true)
		_ov_ring(ext.x, ext.y, ext.r * 0.6, 0.25, Color(1, 1, 1, 0.8))
		_ov_rect(ext.x - 12, ext.y, PI / 2, -20, 20, 2.5, Color(1, 1, 1, 0.85))
		_ov_rect(ext.x + 12, ext.y, PI / 2, -20, 20, 2.5, Color(1, 1, 1, 0.85))
		_ov_rect(ext.x, ext.y, 0, -12, 12, 2.5, Color(1, 1, 1, 0.85))
	## 목표 구역
	for o in map.objs:
		if is_dest(o) or d2(o, p) > 900:
			continue
		var c: Color = Color("#5f9c32") if o.done else Color("#4fa3d9") if o.type == "cap" else gold
		_ov_disc(o.x, o.y, o.r, Color(c, 0.1 if o.done else 0.16))
		_ov_ring(o.x, o.y, o.r, 0.22, c, true)
		if o.type == "cap" and not o.done and o.prog > 0:
			_ov_ring(o.x, o.y, o.r, 0.5, gold, false, -PI / 2, TAU * o.prog)
	## 경계 중인 적의 시야 (발각 정도에 따라 노랑→빨강)
	for e in en:
		if e.st == "alert" or e.st == "call" or d2(e, p) > 460:
			continue
		var aw = clampf(e.aw, 0, 1)
		var col = Color(1, 1, 1, 0.09) if aw <= 0.02 else Color(1, (200 - aw * 160) / 255.0, 0.16, 0.12 + aw * 0.22)
		_ov_fan(e.x, e.y, e.T.vis, e.face, 0.85, col)
	if p.boostT > 0:
		_ov_ring(p.x, p.y, 16, 0.12, Color("#a6dc68"), true, 0.0, TAU, 20)
	## 증원 요청 중인 무전병
	if rcall != null:
		var k: float = 1.0 - rcall.callT / rcall.callMax
		_ov_ring(rcall.x, rcall.y, 22, 0.12, Color(1, 0.23, 0.16, 0.45))
		_ov_ring(rcall.x, rcall.y, 22, 0.25, Color("#ff3a2a"), false, -PI / 2, TAU * k, 24)
	## 화염·치료 구역
	for z in zones:
		var al = minf(1.0, z.life)
		if z.k == "fire":
			_ov_disc(z.x, z.y, z.r, Color(0.09, 0.05, 0.03, 0.4 * al))
		else:
			_ov_disc(z.x, z.y, z.r, Color(0.37, 0.61, 0.2, 0.22 * al))
			_ov_ring(z.x, z.y, z.r, 0.2, Color(0.65, 0.86, 0.41, al), true)
			_ov_rect(z.x, z.y, 0, -14, 14, 4, Color(0.65, 0.86, 0.41, al))
			_ov_rect(z.x, z.y, PI / 2, -14, 14, 4, Color(0.65, 0.86, 0.41, al))
	for v in vort:
		_ov_disc(v.x, v.y, v.r * (0.3 + 0.1 * sin(t * 5)), Color(1, 0.54, 0.1, 0.3))
		for i in 3:
			_ov_ring(v.x, v.y, v.r * (1.0 - fmod(t * 1.2 + i / 3.0, 1.0)), 0.18, Color(0.95, 0.76, 0.1, 0.8))
	for tl in tele:
		var k: float = 1.0 - tl.t / tl.max
		_ov_disc(tl.x, tl.y, tl.r, Color(1, 0.16, 0.16, 0.22))
		_ov_ring(tl.x, tl.y, tl.r, 0.15, Color("#ff3a2a"))
		_ov_ring(tl.x, tl.y, tl.r * k, 0.12, Color("#ff9a8a"))
	for c in calls:
		if c.r <= 0:
			continue
		var k: float = c.t / c.max
		if c.get("w", false):
			## 실제 피해 반경: 테두리 고정, 안쪽이 시간에 따라 차오른다
			var blink = 0.5 + 0.5 * sin(t * (10.0 + 20.0 * (1.0 - k)))
			_ov_disc(c.x, c.y, c.r, Color(c.col, 0.1 + 0.08 * blink))
			_ov_disc(c.x, c.y, c.r * (1.0 - k), Color(c.col, 0.22), 24)
			_ov_ring(c.x, c.y, c.r, 0.28, Color(c.col, 0.95))
		else:
			_ov_disc(c.x, c.y, c.r, Color(c.col, 0.14))
			_ov_ring(c.x, c.y, c.r, 0.15, c.col, true)
			_ov_ring(c.x, c.y, c.r * k, 0.2, c.col)
	if dbg_trace and trace != null:
		for c in trace.cells:
			var x0 = c.x * TS + 2
			var y0 = c.y * TS + 2
			var x1 = x0 + TS - 4
			var y1 = y0 + TS - 4
			var cc = Color(0.2, 0.7, 1.0, 0.3)
			_ov_tri(p3(x0, y0, 0.05), p3(x1, y0, 0.05), p3(x1, y1, 0.05), cc)
			_ov_tri(p3(x0, y0, 0.05), p3(x1, y1, 0.05), p3(x0, y1, 0.05), cc)
		_ov_ring(trace.x, trace.y, p.w.range, 0.15, Color(0.25, 0.75, 1.0, 0.8), true, 0.0, TAU, 60)
		for e in trace.blocked:
			if is_instance_valid(e.node):
				_ov_rect(trace.x, trace.y, atan2(e.y - trace.y, e.x - trace.x), 0, Vector2(e.x - trace.x, e.y - trace.y).length(), 2.0, Color(1, 0.25, 0.2, 0.8))
		if trace.pick != null:
			var tp = trace.pick
			_ov_rect(trace.x, trace.y, atan2(tp.y - trace.y, tp.x - trace.x), 0, Vector2(tp.x - trace.x, tp.y - trace.y).length(), 3.0, Color(0.4, 1.0, 0.35, 0.95))
			_ov_ring(tp.x, tp.y, 18, 0.3, Color(0.4, 1.0, 0.35, 1.0))
	## 전투기 그림자 (기체 실루엣)
	for j in jets:
		var sc: float = 30.0 if j.big else 26.0
		var sx: float = j.x + 18
		var sy: float = j.y + 10
		var ca2 = cos(j.ang)
		var sa2 = sin(j.ang)
		var P = func(u: float, v: float) -> Vector3: return p3(sx + (ca2 * u - sa2 * v) * sc / 10.0, sy + (sa2 * u + ca2 * v) * sc / 10.0, 0.06)
		var sh = Color(0, 0, 0, 0.32)
		var wing = 22.0 if j.big else 17.0
		_ov_tri(P.call(20, 0), P.call(-16, -2), P.call(-16, 2), sh)
		_ov_tri(P.call(4, 0), P.call(-6, -wing), P.call(-10, 0), sh)
		_ov_tri(P.call(4, 0), P.call(-6, wing), P.call(-10, 0), sh)
		_ov_tri(P.call(-12, 0), P.call(-18, -7), P.call(-18, 7), sh)
	for b in bombs:
		var k: float = b.t / b.d
		_ov_disc(b.x, b.y, 4.0 + 8.0 * k, Color(0, 0, 0, 0.2 + 0.3 * k), 12)
	for l in marks:
		_ov_ring(l.x, l.y, 34, 0.15, Color("#ff3a2a"), true, 0.0, TAU, 24)
		_ov_rect(l.x, l.y, 0, -44, 44, 0.8, Color("#ff3a2a"))
		_ov_rect(l.x, l.y, PI / 2, -44, 44, 0.8, Color("#ff3a2a"))
	for l in lobs:
		_ov_ring(l.x1, l.y1, 20 * (1 - l.t / l.d) + 6, 0.12, Color(1, 0.23, 0.16, 0.6), false, 0.0, TAU, 16)
	for f in fx:
		if f.get("c") == null:
			_ov_disc(f.x, f.y, f.r * (0.6 + f.t / f.d * 0.5), Color(0.16, 0.14, 0.12, (1.0 - f.t / f.d) * 0.45), 20)
		else:
			var k: float = f.t / f.d
			_ov_disc(f.x, f.y, f.r * (0.4 + k * 0.6), Color(f.c, (1 - k) * 0.5), 24)
			_ov_ring(f.x, f.y, f.r * (0.5 + k * 0.5), 0.2, Color(1, 1, 1, 1 - k))
	## 수동 조준
	if aim != null:
		var s: Dictionary = aim.s
		_ov_ring(p.x, p.y, aim_range(s), 0.1, Color(1, 1, 1, 0.5), true, 0.0, TAU, 60)
		if aim.has:
			var tg = aim_target()
			var B: float = p.m.blast
			if s.aim == "line":
				var L: float = (s.n - 1) * s.gap
				var r: float = s.rad * B
				_ov_rect(tg.x, tg.y, tg.ang, -r, L + r, r, Color(gold, 0.18))
				_ov_rect(tg.x, tg.y, tg.ang, 0, L, 1.5, gold)
			else:
				var r: float = s.rad * (B if s.aim == "pt" else 1.0)
				_ov_disc(tg.x, tg.y, r, Color(gold, 0.18))
				_ov_ring(tg.x, tg.y, r, 0.15, gold, true)
	overlay_im.surface_end()


func _tr_seg(x0: float, y0: float, x1: float, y1: float, h: float, w: float, col: Color) -> void:
	var a = p3(x0, y0, h)
	var b = p3(x1, y1, h)
	var d = b - a
	if d.length() < 0.001:
		return
	var n = Vector3(-d.z, 0, d.x).normalized() * w * 0.5
	tracer_im.surface_set_color(col)
	tracer_im.surface_add_vertex(a - n)
	tracer_im.surface_add_vertex(a + n)
	tracer_im.surface_add_vertex(b + n)
	tracer_im.surface_add_vertex(a - n)
	tracer_im.surface_add_vertex(b + n)
	tracer_im.surface_add_vertex(b - n)


func _draw_tracers() -> void:
	tracer_im.clear_surfaces()
	tracer_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	tracer_im.surface_add_vertex(Vector3.ZERO)
	tracer_im.surface_add_vertex(Vector3.ZERO)
	tracer_im.surface_add_vertex(Vector3.ZERO)
	var bc = Color("#ff6a1a") if p.evo.has("sg") else Color("#7fe3ff") if p.evo.has("rail") else Color("#ffb03a")
	var wc = wcol()
	for b in bul:
		if b.get("evo", false):
			## 진화 탄: 굵고 긴 색 궤적
			_tr_seg(b.x, b.y, b.x - b.vx * 0.06, b.y - b.vy * 0.06, LIFT, 0.5, Color(wc, 0.45))
			_tr_seg(b.x, b.y, b.x - b.vx * 0.035, b.y - b.vy * 0.035, LIFT + 0.01, 0.16, Color(1, 1, 0.95, 1))
			continue
		_tr_seg(b.x, b.y, b.x - b.vx * 0.032, b.y - b.vy * 0.032, LIFT, 0.22, Color(bc, 0.55))
		_tr_seg(b.x, b.y, b.x - b.vx * 0.018, b.y - b.vy * 0.018, LIFT + 0.01, 0.08, Color(1, 0.97, 0.85, 1))
	for bm in beams:
		var k: float = 1.0 - bm.t / bm.d
		_tr_seg(bm.x0, bm.y0, bm.x1, bm.y1, LIFT, bm.w * (0.4 + 0.6 * k), Color(bm.c, 0.7 * k))
		_tr_seg(bm.x0, bm.y0, bm.x1, bm.y1, LIFT + 0.01, bm.w * 0.3 * k, Color(1, 1, 1, k))
	for b in eb:
		_tr_seg(b.x, b.y, b.x - b.vx * 0.09, b.y - b.vy * 0.09, LIFT, 0.22, Color(1, 0.23, 0.1, 0.7))
		_tr_seg(b.x, b.y, b.x - b.vx * 0.04, b.y - b.vy * 0.04, LIFT + 0.01, 0.08, Color(1, 0.85, 0.78, 1))
	for a in arcs:
		var mx: float = (a.x1 + a.x2) / 2 + (randf() - 0.5) * 24
		var my: float = (a.y1 + a.y2) / 2 + (randf() - 0.5) * 24
		_tr_seg(a.x1, a.y1, mx, my, LIFT, 0.25, Color(0.5, 0.8, 1, 0.8))
		_tr_seg(mx, my, a.x2, a.y2, LIFT, 0.25, Color(0.5, 0.8, 1, 0.8))
	for l in marks:
		## 상공 건십에서 내려오는 사격 광선
		var a = p3(l.x + 500, l.y - 700, 40)
		var b = p3(l.x + (randf() - 0.5) * 30, l.y + (randf() - 0.5) * 30, 0.2)
		var n = Vector3(0.12, 0, 0.12)
		tracer_im.surface_set_color(Color(1, 0.88, 0.54, 0.6))
		tracer_im.surface_add_vertex(a - n)
		tracer_im.surface_add_vertex(a + n)
		tracer_im.surface_add_vertex(b + n)
		tracer_im.surface_add_vertex(a - n)
		tracer_im.surface_add_vertex(b + n)
		tracer_im.surface_add_vertex(b - n)
	tracer_im.surface_end()


## 건물 뒤에 가려져도 보이는 플레이어 표시 (깊이 검사 없는 층)
func _player_marker() -> void:
	var c = p3(p.x, p.y, 0.08)
	var seg = 24
	for i in seg:
		var a0 = i / float(seg) * TAU
		var a1 = (i + 1) / float(seg) * TAU
		var r0 = 0.62
		var r1 = 0.74
		var q = [c + Vector3(cos(a0) * r0, 0, sin(a0) * r0), c + Vector3(cos(a0) * r1, 0, sin(a0) * r1), c + Vector3(cos(a1) * r1, 0, sin(a1) * r1), c + Vector3(cos(a1) * r0, 0, sin(a1) * r0)]
		bar_im.surface_set_color(Color(0.95, 0.76, 0.1, 0.55))
		for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			bar_im.surface_add_vertex(v)
	var top = p3(p.x, p.y, 2.6)
	var r = cam.global_basis.x * 0.22
	var u = cam.global_basis.y * 0.3
	bar_im.surface_set_color(Color(0.95, 0.76, 0.1, 0.9))
	bar_im.surface_add_vertex(top - r + u)
	bar_im.surface_add_vertex(top + r + u)
	bar_im.surface_add_vertex(top)


## 체력 막대 (항상 위에 보이게, 카메라를 향한 사각형)
func _bar(pos: Vector3, w: float, frac: float, col: Color) -> void:
	var r = cam.global_basis.x * w * 0.5
	var u = cam.global_basis.y * 0.07
	var q = func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cc: Color):
		bar_im.surface_set_color(cc)
		bar_im.surface_add_vertex(a)
		bar_im.surface_add_vertex(b)
		bar_im.surface_add_vertex(c)
		bar_im.surface_add_vertex(a)
		bar_im.surface_add_vertex(c)
		bar_im.surface_add_vertex(d)
	q.call(pos - r - u * 1.4, pos + r - u * 1.4, pos + r + u * 1.4, pos - r + u * 1.4, Color(0.03, 0.035, 0.04, 0.85))
	var rr = r * (frac * 2.0 - 1.0)
	q.call(pos - r * 0.95 - u, pos + rr * 0.95 - u, pos + rr * 0.95 + u, pos - r * 0.95 + u, col)


func _draw_bars() -> void:
	bar_im.clear_surfaces()
	bar_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	bar_im.surface_add_vertex(Vector3.ZERO)
	bar_im.surface_add_vertex(Vector3.ZERO)
	bar_im.surface_add_vertex(Vector3.ZERO)
	var red = Color("#e2412f")
	_player_marker()
	for e in en:
		if (e.type == "tk" or e.type == "sh") and e.hp < e.maxhp and e.node.visible:
			_bar(p3(e.x, e.y, 3.2 if e.type == "tk" else 2.4), 1.8 if e.type == "tk" else 1.1, clampf(e.hp / e.maxhp, 0, 1), red)
	for o in map.objs:
		if is_dest(o) and not o.done and o.hp < o.maxhp:
			_bar(p3(o.x, o.y, 5.2 if o.type == "nest" else 4.0), 3.0, clampf(o.hp / o.maxhp, 0, 1), red)
	for tu in turrets:
		_bar(p3(tu.x, tu.y, 1.9), 1.2, tu.life / tu.max, Color("#4fa3d9"))
	if p.reload > 0:
		_bar(p3(p.x, p.y, 2.3), 1.0, 1.0 - p.reload / (p.w.reload * p.m.rl), Color("#f2c21b"))
	bar_im.surface_end()


func _draw_particles() -> void:
	var n = mini(pt.size(), parts_mm.instance_count)
	for i in n:
		var q: Dictionary = pt[i]
		var k: float = q.t / q.d
		var r: float = (q.r + q.g * q.t) * K
		var h: float = q.h + q.get("rise", 0.0) * q.t + (q.t * 1.5 if q.g > 0 else 0.0)
		parts_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * r), p3(q.x, q.y, h)))
		var c: Color = q.c
		parts_mm.set_instance_color(i, Color(c.r, c.g, c.b, (1.0 - k) * (0.55 if q.g > 0 else 1.0)))
	parts_mm.visible_instance_count = n
	var gn = mini(gems.size(), gems_mm.instance_count)
	for i in gn:
		var g: Dictionary = gems[i]
		var b = sin(t * 5 + g.x) * 0.08
		var sc = 2.2 if g.lv else 1.0
		gems_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, t * 2 + g.x).scaled(Vector3(sc, sc * 1.6, sc)), p3(g.x, g.y, 0.45 + b)))
		gems_mm.set_instance_color(i, Color("#f2c21b") if g.lv or g.v > 3 else Color("#62d0f0"))
	gems_mm.visible_instance_count = gn
	var sn = mini(scorch.size(), scorch_mm.instance_count)
	for i in sn:
		var s: Dictionary = scorch[i]
		scorch_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s.r * K, 1, s.r * K * 0.9)), p3(s.x, s.y, 0.03)))
	scorch_mm.visible_instance_count = sn


## 폭발 불덩이 + 순간 조명
func _draw_fx() -> void:
	var used = 0
	var lights: Array = []
	for f in fx:
		if f.get("c") != null:
			continue
		if used >= fx_pool.size():
			break
		var k: float = f.t / f.d
		var a = 1.0 - k
		var mi: MeshInstance3D = fx_pool[used]
		used += 1
		mi.visible = true
		var R0: float = f.r * K * (0.45 + k * 0.6)
		mi.position = p3(f.x, f.y, f.r * K * (0.2 + 0.4 * k))
		mi.scale = Vector3(R0, R0 * 0.85, R0)
		var m: StandardMaterial3D = mi.material_override
		m.albedo_color = Color(1.0, 0.42 + 0.5 * a * a, 0.08 + 0.6 * a * a * a, minf(1.0, a * 1.3))
		lights.append([f, a])
	for i in range(used, fx_pool.size()):
		fx_pool[i].visible = false
	lights.sort_custom(func(x, y): return x[0].r * x[1] > y[0].r * y[1])
	for i in light_pool.size():
		var l: OmniLight3D = light_pool[i]
		if i < lights.size():
			var f: Dictionary = lights[i][0]
			l.visible = true
			l.position = p3(f.x, f.y, 2.0)
			l.omni_range = f.r * K * 2.4
			l.light_energy = 4.0 * lights[i][1]
		else:
			l.visible = false
	## 화염 구역 불빛
	var zi = lights.size()
	for z in zones:
		if z.k == "fire" and zi < light_pool.size():
			var l: OmniLight3D = light_pool[zi]
			zi += 1
			l.visible = true
			l.position = p3(z.x, z.y, 1.2)
			l.omni_range = z.r * K * 1.8
			l.light_energy = 1.4 * minf(1.0, z.life) * (0.85 + randf() * 0.3)
