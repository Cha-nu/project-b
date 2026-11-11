extends Node3D
## 전투 월드. 논리는 프로토타입(index.html)의 update()를 거의 그대로 옮겼다.
## 논리 좌표 (x, y)는 게임 단위, 3D 위치는 (x*K, h, y*K).

signal ended(win: bool, rows: Array, total: int, stars: int)
signal leveled(opts: Array)

const Data := preload("res://scripts/data.gd")
const WG := preload("res://scripts/worldgen.gd")
const ML := preload("res://scripts/meshlib.gd")
const MK := preload("res://scripts/modelkit.gd")
const AC := preload("res://scripts/actors.gd")

const K := WG.K
const WORLD := WG.WORLD
const TS := 50.0
const TN := 60
const AAR := 430.0 ## 방공포 교란 반경
const JAMR := 650.0 ## 미니맵 교란기 반경
const EVO_DUR := 1.3 ## 진화 알림이 떠 있는 시간
const SHARE_ALERT := 380.0 ## 발각 정보 공유: 이 안의 적은 바로 교전
const SHARE_SUS := 800.0 ## 이 안의 적은 플레이어 위치로 수색하러 온다
const PEND := 0.6  ## 겹치는 부호 대기 시간
const LIFT := 1.58 ## 탄환 높이(m)
## 거치 기관총 (올라타 있는 동안 주무기 대신 쓴다)
const HMG := {id = "hmg", name = "거치 기관총", rate = 15.0, dmg = 15.0, speed = 640.0, spread = 0.07, mag = 999, reload = 0.0, pellets = 1, pierce = 2, range = 380.0, kb = 34.0, noise = 330.0}
## 엄폐물 내구도 (폭발로만 깎인다. 총알은 통하지 않는다)
const PROP_HP := {tree = 80.0, pine = 80.0, palm = 80.0, sand = 150.0, car = 160.0, cont = 450.0, rock = 700.0, bld = 800.0}
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
var font: Font

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
## 교란기 파괴 보상: 미니맵에 주변 적 표시 / 군수공장 파괴 보상: 증원에서 전차·드론 제외
var radar := false
var no_armor := false
var shareT := 0.0
## 증원이 온 뒤 전투 음악을 이어 갈 시간
var musicT := 0.0
var jam_warned := false
## 보스 (스테이지 5·8·10). 적 목록에 들어 있는 같은 Dictionary를 가리킨다
var boss = null
## 경보 사이렌 (단말기 2단계 해킹 뒤): 남은 시간, 다음 울림까지, 울리는 자리
var sirenT := 0.0
var siren_next := 0.0
var siren_at := Vector2.ZERO
var siren_light: OmniLight3D
## 저격 지원(남은 시간·다음 사격), 전자전·위성 정찰 남은 시간
var snipe = null
var empT := 0.0
var satT := 0.0
## 방공포가 쏘아 올린 요격 미사일
var sams: Array = []
## 탈출 신호탄: 쏘아 올린 뒤로는 맵 전체의 적이 플레이어에게 몰려온다
var flare_node: Node3D
var flareT := -1.0
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
var chute_node: Node3D
const DROP := 1.9 ## 낙하산 강하 시간(초). 출격할 때와 쓰러져 다시 투입될 때
const DROP_H := 12.0 ## 강하 시작 높이(m)
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
## 공격헬기(지원요청): 플레이어 주위 상공을 선회하며 사격
var gs = null
## 부대원(진급 보급): {role, x, y, face, fireT, node, mv, elite, hackT, hackC}
var squad: Array = []
const SQ_ROLE := ["rf", "sup", "eng", "med"]
const SQ_SLOT := [Vector2(-34, -24), Vector2(-34, 24), Vector2(-62, 0), Vector2(-64, 44)]
const SQ_W := {speed = 540.0, range = 270.0, kb = 12.0}
## 부대원·드론은 적 탄환과 포탄에 맞아 쓰러지고, 대기 시간이 지나면 다시 온다 (down: 남은 복귀 시간)
const ALLY_NAME := {rf = "소총수", sup = "지원병", eng = "공병", med = "의무병", gun = "사격 드론", flame = "화염방사 드론", arc = "전기 드론", guard = "방어 드론"}
const SQ_HP := 70.0
const SQ_HP_ELITE := 120.0
const DRONE_HP := 30.0
const SQ_BACK := 20.0
const SQ_BACK_ELITE := 12.0
const DRONE_BACK := 12.0
## 포위 돌파: {a = 탈출 방향, t = 남은 시간}. 부대원이 이 방향의 적에게 화력을 모은다
var breakout = null
var breakT := 0.0
## 아군 기갑(지원요청 경전차·전차): {k, x, y, r, ha, ta, fireT, mgT, burst, rec, life, node}
var avs: Array = []
## 자폭 드론 (드론 편대 Lv2부터 대기 시간마다 출격)
var kamis: Array = []
var kamiT := 4.0
var bombs: Array = []
var siegeN := 0
const EVO_COL := {comms = "#62d0f0", ar = "#ffd04a", sg = "#ff5a1a", lmg = "#ffb03a", rail = "#6fe8ff", aim = "#a6dc68", gren = "#ff9d1a", drone = "#62d0f0", taser = "#8fc8ff", squad = "#4fa3d9"}
var heli_node: Node3D
## 자동 점검에서 모델을 가까이 찍을 때 쓰는 카메라 당김
var dbg_zoom := 0.0
var lobT := 0.0

## 모스 입력 상태
var M := {down = false, t0 = 0.0, buf = "", last = 0.0, pid = 0, fired = false, miss = 0, thr = 0.15, queue = null, pend = null, pendT = 0.0}
## 이동 입력 (터치 조이스틱)
var joy := {id = -1, ox = 0.0, oy = 0.0, x = 0.0, y = 0.0}
var aim_touch := -1


func _ready() -> void:
	font = preload("res://scripts/ui.gd").font(true)
	env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.94
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 0.95
	## 색 보정: 채도를 빼고 대비를 올린 건조한 전술 톤
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.15
	e.adjustment_saturation = 0.8
	e.fog_enabled = true
	e.fog_density = 0.0048
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.rotation_degrees = Vector3(-40, -38, 0)
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


## 총구 위치: (x, y)에서 a 방향으로 fwd만큼 앞, lat만큼 오른쪽 (모델의 총구 끝과 맞춘 값을 넘긴다)
static func muzzle(x: float, y: float, a: float, fwd: float, lat := 2.6) -> Vector2:
	return Vector2(x + cos(a) * fwd - sin(a) * lat, y + sin(a) * fwd + cos(a) * lat)


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
	Synth.music(0)
	flare_node = null
	flareT = -1.0


func _setup_env(bm: Dictionary) -> void:
	var e = env.environment
	e.background_color = Color(bm.sky)
	## 그늘은 차갑게, 볕은 따뜻하게 (그림자가 푸르스름해져 입체감이 산다)
	e.ambient_light_color = Color(bm.amb).lerp(Color("#8a98b4"), 0.5)
	e.ambient_light_energy = 0.56
	e.fog_light_color = Color(bm.fog).lerp(Color("#9aa0a4"), 0.45)
	sun.light_color = Color(bm.sun).lerp(Color.WHITE, 0.35)
	sun.light_energy = 1.42 if not bm.get("snow", false) else 1.12


func _build(seed_v: int) -> void:
	_clear()
	map = WG.gen_map(seed_v, stage)
	## 임무 구조물도 엄폐물처럼 길을 막는다 (파괴 목표는 부서지면 통과 가능)
	var CB = {term = [11.0, 8.0, 10.0], cap = [15.0, 15.0, 10.0], nest = [36.0, 26.0, 30.0], fac = [53.0, 38.0, 30.0]}
	for o in map.objs:
		var c: Dictionary
		if o.type == "boss":
			continue
		if CB.has(o.type):
			c = {kind = "obj", x = o.x, y = o.y, hw = CB[o.type][0], hh = CB[o.type][1], h = CB[o.type][2], o = o}
		else:
			c = {kind = "obj", x = o.x, y = o.y, r = 25.0, h = 10.0, o = o}
		map.rg[int(o.y / 100) * 30 + int(o.x / 100)].append(c)
	_setup_env(map.biome)
	WG.build_world(world_root, map)
	WG.dress_sites(world_root, map)
	for o in map.objs:
		var n = WG.build_struct(o)
		world_root.add_child(n)
		o.node = n
		var lb = _label(26)
		lb.position = p3(o.x, o.y, {nest = 6.0, cap = 10.5, aa = 4.6, jam = 7.2, fac = 7.4}.get(o.type, 4.0))
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
## 스테이지 1~10. 올라갈수록 적이 단단해지고 진지 경계가 삼엄해진다. diff(0~2)는 표시용 등급
var stage := 1


## 스테이지 진행도 0(1단계)~1(10단계)
func lv() -> float:
	return clampf((stage - 1) / 9.0, 0.0, 1.0)


## 스테이지별 적 체력 배수. 뒤로 갈수록 가파르게 올라 기본 무기로는 못 버틴다
## (1단계 0.85 → 3단계 1.1 → 5단계 1.45 → 8단계 2.1 → 10단계 2.6). 무기 등급을 올리면 화력이 2등급 약 1.25배, 3등급 약 1.6배라
## 3~5단계부터 2등급, 8단계부터 3등급이 있어야 처치 시간이 1단계 수준으로 돌아온다. 나머지는 상위 지원요청으로 메운다.
## 보스는 지원요청 화력으로 잡는 상대라 완만하게 오른다
func hp_mul(is_boss := false) -> float:
	if is_boss:
		return 0.85 + 1.0 * lv()
	return 0.85 + 1.75 * pow(lv(), 1.3)


func new_game(seed_v: int, d := 1, st := 1) -> void:
	diff = d
	stage = st
	preview_mode = false
	_build(seed_v)
	var w: Dictionary = Data.weapon(Save.d.w)
	t = 0.0; rt = 0.0; run = true; pause = ""; over = false; kills = 0; shake = 0.0; hs = 0.0; flash = 0.0; spawnT = 2.0; evoT = 0.0; comms = null; gs = null; _evo_snd = -1.0
	combo = 0; comboT = 0.0; best = 0; bonus = 0; aim = null; heat = 0; rcd = 0.0; rcall = null; silent = 0; alertN = 0; susN = 0
	last_seen = null; intel = false; reinf_mul = 1.0; cd_mul = 1.0; radar = false; no_armor = false; shareT = 0.0; musicT = 0.0; jam_warned = false; boss = null; sirenT = 0.0; snipe = null; empT = 0.0; satT = 0.0
	p = {x = map.start.x, y = map.start.y, r = 11.0, hp = 120.0, maxhp = 120.0, w = w, aim = -PI / 2, face = -PI / 2, fx = 0.0, fy = -1.0,
		ammo = w.mag, reload = 0.0, fireT = 0.0, xp = 0, lvl = 1, next = 5, lives = 2, shieldT = 0.0, boostT = 0.0, inv = 1.5, dropT = DROP, hurtT = 0.0,
		grenT = 2.0, tasT = 2.0, up = {}, evo = {}, m = {}, muz = 0.0, mv = false, mount = null, shots = 0}
	strats = []
	for id in Save.d.eq:
		var s: Dictionary = Data.strat(id).duplicate()
		s.t = 0.0
		strats.append(s)
	breakout = null; breakT = 0.0; kamiT = 4.0
	for a in [squad, kamis, avs, en, bul, eb, gems, crates, calls, timers, zones, marks, mines, turrets, drones, mis, lobs, vort, tele, arcs, fx, scorch, fl, pt, beams, jets, bombs, sams]:
		a.clear()
	grid = []
	grid.resize(TN * TN)
	for i in TN * TN:
		grid[i] = []
	ext = {x = map.ext.x, y = map.ext.y, r = 100.0, state = "locked", t = 0.0, ship = 0.0, gunT = 0.0, clearT = 0.0, out = 0.0, landed = false}
	recalc()
	for o in map.objs:
		if o.type == "term" or o.type == "cap":
			o.code = term_code()
		o.hacked = false
		o.hackN = 0
		o.hackT = 0.0
		o.scoutT = 0.0
	player_node = AC.soldier("pl")
	dyn.add_child(player_node)
	shield_node = MeshInstance3D.new()
	shield_node.mesh = ML.sph_mesh(1.0, 16, 8)
	shield_node.material_override = ML.mat("#62d0f0", 1.2, 0.25, true)
	shield_node.scale = Vector3(1.6, 1.9, 1.6)
	shield_node.position.y = 1.15
	shield_node.visible = false
	player_node.add_child(shield_node)
	chute_node = AC.chute()
	chute_node.position.y = 1.75
	chute_node.visible = false
	player_node.add_child(chute_node)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color("#ffc070")
	muzzle_light.omni_range = 5.0
	muzzle_light.position = Vector3(1.2, 1.4, 0.15)
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
	if boss != null:
		banner("작전명 「%s」 개시. %s을(를) 격파하고 탈출하라" % [Data.BRIEF[clampi(stage - 1, 0, Data.BRIEF.size() - 1)].op, boss.T.n])
	else:
		banner("작전명 「%s」 개시. 단말기 2곳을 해킹하고 탈출하라" % Data.BRIEF[clampi(stage - 1, 0, Data.BRIEF.size() - 1)].op)


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
	## 드론 편대: 레벨마다 종류가 하나씩 는다 (사격 → 자폭 → 화염방사 → 전기 → 방어). 자폭 드론은 따라다니지 않고 때마다 출격한다
	var dl: int = L.call("drone")
	var want := {gun = (3 if p.evo.has("drone") else 1) if dl >= 1 else 0, flame = 1 if dl >= 3 else 0, arc = 1 if dl >= 4 else 0, guard = 1 if dl >= 5 else 0}
	const DCOL := {gun = "#4fa3d9", flame = "#ff7a1a", arc = "#b9a6ff", guard = "#7fe0a0"}
	var changed := false
	for k in want:
		var have: int = drones.filter(func(d): return d.k == k).size()
		for i in range(drones.size() - 1, -1, -1):
			if have > want[k] and drones[i].k == k:
				drones[i].node.queue_free()
				drones.remove_at(i)
				have -= 1
				changed = true
		while have < want[k]:
			var dn = AC.quad(DCOL[k], "#3a4450")
			dyn.add_child(dn)
			drones.append({k = k, a = 0.0, fireT = 0.0, ammo = 24, perm = true, life = 1.0, x = p.x, y = p.y, node = dn, nT = -9.0, hp = DRONE_HP, maxhp = DRONE_HP, down = 0.0})
			have += 1
			changed = true
	if changed:
		for i in drones.size():
			drones[i].a = i * TAU / drones.size()
	## 부대원: 레벨마다 한 명씩 (소총수 → 지원병 → 공병 → 의무병). 진화하면 전원 특수부대 장비로 바뀐다
	var elite: bool = p.evo.has("squad")
	if squad.size() > 0 and squad[0].elite != elite:
		for sm in squad:
			sm.node.queue_free()
		squad.clear()
	while squad.size() < mini(L.call("squad"), SQ_ROLE.size()):
		var sn = AC.soldier("ae" if elite else "al")
		dyn.add_child(sn)
		var ja = randf() * TAU
		squad.append({role = SQ_ROLE[squad.size()], x = p.x + cos(ja) * 40, y = p.y + sin(ja) * 40, r = 9.0, face = p.face, fireT = 0.0, node = sn, mv = false, elite = elite, hackT = 0.0, hackC = "", nT = -9.0, hp = SQ_HP_ELITE if elite else SQ_HP, maxhp = SQ_HP_ELITE if elite else SQ_HP, down = 0.0})
	while squad.size() > L.call("squad"):
		squad.pop_back().node.queue_free()


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


## 수동 재장전 (탄약 칸 터치 / R 키). 탄창이 가득하거나 이미 장전 중이면 아무 일도 없다
func reload_now() -> void:
	if not active or not run or pause != "" or p.mount != null or p.evo.has("lmg"):
		return
	if p.reload > 0 or p.ammo >= mag_size():
		return
	p.reload = p.w.reload * p.m.rl
	Synth.beep(420, 0.05, "square", 0.04)
	Synth.beep(300, 0.07, "square", 0.04, 0.0, 0.08)
	_vib(15)


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
	return o.type == "nest" or o.type == "aa" or o.type == "jam" or o.type == "fac"


## 미니맵 교란 중인지 (교란기가 살아 있으면 맵 전체가 교란된다)
func in_jam() -> bool:
	if not active:
		return false
	for o in map.objs:
		if o.type == "jam" and not o.done:
			return true
	return false


## 교전 난이도부터는 방공포가 살아 있는 동안 맵 어디서든 지원요청이 요격당한다.
## 쓸 수 없다는 표시는 띄우지 않는다. 불러 보면 미사일이 떨어지고 전투기가 쫓겨난다
func aa_global() -> bool:
	if not active or stage < 3:
		return false
	return _aa_src() != null


## 요격 미사일을 쏘는 곳: 방공포 진지 또는 방공 포탑이 살아 있는 요새
func _aa_src():
	for o in map.objs:
		if o.type == "aa" and not o.done:
			return o
	if boss != null and boss.hp > 0 and boss.get("aa", false):
		return boss
	return null


func in_aa() -> bool:
	if stage >= 3:
		return false
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
				if k.get("dead", false) or (k.has("o") and k.o.done and is_dest(k.o)):
					continue
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
				if k.has("hw") and k.h >= 16 and absf(x - k.x) < k.hw and absf(y - k.y) < k.hh and not k.get("dead", false) and not (k.has("o") and k.o.done):
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
				if not k.has("hw") or k.h < 16 or k.get("dead", false) or (k.has("o") and k.o.done):
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
	## 스테이지에 아직 안 풀린 종류는 아래 단계로 바뀌어 나온다 (예: 3단계의 전차 → 경전차). 바꿀 것도 없으면 안 나온다
	type = Data.unlocked(type, stage)
	if type == "":
		return null
	var T: Dictionary = Data.ET[type]
	if x == null:
		var a: float = randf() * TAU if ang == null else ang + (randf() - 0.5) * 0.7
		var d = 520.0 + randf() * 90.0
		x = clampf(p.x + cos(a) * d, 20, WORLD - 20)
		y = clampf(p.y + sin(a) * d, 20, WORLD - 20)
		if Vector2(x - p.x, y - p.y).length() < 300:
			return null
	var hp: float = T.hp * (1 + t / 300.0) * hp_mul(T.has("boss"))
	var node: Node3D
	if type == "tk":
		node = AC.tank()
	elif type == "sp":
		node = AC.spg()
	elif T.has("boss"):
		node = AC.boss(type)
	elif type == "sn":
		node = AC.sniper(map.biome.g)
	elif type == "lt":
		node = AC.ltank()
	elif type == "ml":
		node = AC.tel()
	elif type == "dr":
		node = AC.quad("#ff3020")
	else:
		node = AC.soldier(type)
	dyn.add_child(node)
	var lb = _label(30)
	lb.visible = false
	node.add_child(lb)
	lb.position.y = 3.8 if T.has("armor") else 3.2
	var e = {type = type, T = T, x = float(x), y = float(y), r = T.r, hp = hp, maxhp = hp, vx = 0.0, vy = 0.0, atk = 0.0, flash = 0.0, shoot = 1 + randf() * 2,
		ph = randf() * TAU, frz = 0.0, burn = 0.0, st = "alert", face = randf() * TAU, aw = 1.0, seen = 0.0, chk = 0.0, sv = 0.0, alT = 0.0, home = "post",
		node = node, lb = lb, walk = 0.0, nT = -9.0, uid = uid_n, px = float(x), py = float(y), bf = 0.0, aimT = 0.0, aimA = 0.0, rec = 0.0, hold = false, burst = 0, bt = 0.0, awake = false, msT = 4.0, bph = 0, side = 1.0, crushT = 0.0, rev = 0.0}
	uid_n += 1
	en.append(e)
	return e


func guard(type: String, x: float, y: float, face: float):
	var e = spawn(type, clampf(x, 30, WORLD - 30), clampf(y, 30, WORLD - 30))
	if e == null:
		return null
	rock_push(e)
	e.st = "post"; e.home = "post"; e.px = e.x; e.py = e.y; e.face = face; e.bf = face; e.aw = 0.0
	if e.T.has("armor"):
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
		if o.type == "boss":
			## 보스 배치 + 호위
			var b = spawn(Data.BOSS[stage], o.x, o.y)
			b.st = "post"; b.home = "post"; b.px = b.x; b.py = b.y; b.aw = 0.0; b.ha = 0.0; b.face = 0.0
			if b.type == "b3":
				b.aa = true
			boss = b
			o.e = b
			for i in 10:
				var ga = i / 10.0 * TAU
				guard(mix.call(), o.x + cos(ga) * (130 + randf() * 60), o.y + sin(ga) * (130 + randf() * 60), ga)
			guard("tk", o.x + 190, o.y + 120, 0.0)
			guard("sp", o.x - 200, o.y - 110, PI)
			continue
		## 진지 경비: 스테이지가 오를수록 사람도, 기갑도 늘어난다
		var n = (6 if is_dest(o) else 5) + int(lv() * 7)
		for i in n:
			var a = i / float(n) * TAU + randf() * 0.4
			var d = (75.0 if is_dest(o) else 60.0) + randf() * 70
			guard(mix.call(), o.x + cos(a) * d, o.y + sin(a) * d, a)
		if is_dest(o):
			var a = randf() * TAU
			## 방공포·교란기는 자주포가, 부대·군수공장은 전차가 지킨다
			guard("sp" if o.type == "aa" or o.type == "jam" else heavy(), o.x + cos(a) * 150, o.y + sin(a) * 150, a)
			if stage >= 5:
				guard("tk", o.x + cos(a + 2.2) * 165, o.y + sin(a + 2.2) * 165, a + 2.2)
			if stage >= 9:
				guard("ml", o.x + cos(a + 3.2) * 190, o.y + sin(a + 3.2) * 190, a + 3.2)
			if stage >= 8:
				guard("sp", o.x + cos(a + 4.2) * 175, o.y + sin(a + 4.2) * 175, a + 4.2)
		elif stage >= 7:
			## 후반에는 주 임무 지점에도 전차가 선다
			var a = randf() * TAU
			guard("tk", o.x + cos(a) * 150, o.y + sin(a) * 150, a)
	## 길리 저격수: 목표에서 조금 떨어져 감시한다 (7단계부터)
	if stage >= Data.UNLOCK.sn:
		for o in map.objs:
			for i in (1 if stage < 9 else 2):
				var sa2 = randf() * TAU
				var sr = 230.0 + randf() * 150
				var se = guard("sn", o.x + cos(sa2) * sr, o.y + sin(sa2) * sr, sa2 + PI)
				if se != null:
					se.shoot = 1.0
	var c = 0
	for tr in 300:
		if c >= 3 + int(lv() * 6):
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
		if c >= 8 + int(lv() * 14):
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
	if e.T.has("boss"):
		## 보스 격파: 연쇄 폭발 + 멈춤 + 보너스
		bonus += 300
		flash = 0.5
		hs = 0.25
		shake = 28.0
		banner("%s 격파!" % e.T.n)
		floater(e.x, e.y, "+300 골드", Color("#f2c21b"), 22)
		var bx: float = e.x
		var by: float = e.y
		for i in 9:
			var ba = i / 9.0 * TAU
			later(0.1 + i * 0.12, func():
				explode(bx + cos(ba) * (30 + i * 6), by + sin(ba) * (30 + i * 6), 70, 200, {noFF = true, fixed = true})
				fx.append({x = bx, y = by, r = 120.0, t = 0.0, d = 0.5, c = Color("#ffd9a0")}))
		Synth.noise(1.6, 0.3, 200)
		Synth.beep(50, 1.4, "sawtooth", 0.08, -20)
	## 동료가 쓰러지는 것을 본 적은 경계에 들어가 그 자리를 살피러 온다 (은밀 처치도 들킬 수 있다)
	for f in en:
		if f.hp <= 0 or is_same(f, e) or f.st == "alert" or f.st == "call" or f.frz > 0:
			continue
		if d2(f, e) < 190 and los(f.x, f.y, e.x, e.y):
			f.st = "sus"
			f.inv = Vector2(e.x, e.y)
			f.aw = maxf(f.aw, 0.55)
			f.lookT = 0.0
			f.alT = 0.0
	## 용의 숨결: 불붙은 적은 죽으면서 터진다
	if e.burn > 0 and p.evo.has("sg"):
		explode(e.x, e.y, 44, 40.0 * p.m.dmg, {noFF = true, small = true})
	if is_same(e, rcall):
		rcall = null
		rcd = maxf(rcd, 8.0)
		## 보상: 지원요청 재사용 대기를 남은 시간의 30% (최소 3초) 줄인다 (화면에는 따로 알리지 않는다)
		for s in strats:
			if s.t > 0:
				s.t = maxf(0.0, s.t - maxf(3.0, s.t * 0.3))
		banner("증원 요청 차단")
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
	puff(e.x, e.y, Color("#ff9d1a") if e.T.has("armor") else Color("#8a2a20"), 18 if e.T.has("armor") else 5)
	if e.T.has("armor"):
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
	blast_props(x, y, r, d)
	for e in en:
		var dx: float = e.x - x
		var dy: float = e.y - y
		var q = maxf(1.0, sqrt(dx * dx + dy * dy))
		if q < r + e.r:
			var kb: float = o.get("kb", 160.0) / (4.0 if e.T.has("armor") else 1.0)
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


## ---------- 지형물 파괴 ----------
## 폭발 반경에 걸린 엄폐물의 내구도를 깎고, 0이 되면 부순다
func blast_props(x: float, y: float, r: float, d: float) -> void:
	var c0 = maxi(0, int((x - r - 80) / 100))
	var c1 = mini(29, int((x + r + 80) / 100))
	var r0 = maxi(0, int((y - r - 80) / 100))
	var r1 = mini(29, int((y + r + 80) / 100))
	var hit: Array = []
	for j in range(r0, r1 + 1):
		for i in range(c0, c1 + 1):
			for k in map.rg[j * 30 + i]:
				if not PROP_HP.has(k.kind) or k.get("dead", false):
					continue
				## 폭발 중심에서 엄폐물 겉면까지의 거리
				var dd: float
				if k.has("hw"):
					dd = Vector2(maxf(0.0, absf(x - k.x) - k.hw), maxf(0.0, absf(y - k.y) - k.hh)).length()
				else:
					dd = maxf(0.0, Vector2(x - k.x, y - k.y).length() - k.r)
				if dd < r:
					hit.append(k)
	for k in hit:
		k.hp = k.get("hp", PROP_HP[k.kind]) - d * (1.0 if k.kind != "bld" or d >= 100 else 0.5)
		if k.hp <= 0:
			_wreck(k)


func _wreck(k: Dictionary) -> void:
	if k.get("dead", false):
		return
	k.dead = true
	var n: Node3D = k.node
	for c in n.get_children():
		c.queue_free()
	var big: bool = k.kind == "bld" or k.kind == "cont"
	var ext: float = maxf(k.hw, k.hh) if k.has("hw") else k.get("vr", k.r)
	## 먼지 고리 + 파편 + 연기
	fx.append({x = k.x, y = k.y, r = ext * 1.6 + 20, t = 0.0, d = 0.6, c = Color("#b8a888")})
	for i in (14 if big else 6):
		if pt.size() < 390:
			var a = randf() * TAU
			var sp = 60.0 + randf() * 180
			pt.append({x = k.x + cos(a) * ext * 0.5, y = k.y + sin(a) * ext * 0.5, vx = cos(a) * sp, vy = sin(a) * sp, t = 0.0, d = 0.6 + randf() * 0.5, c = Color("#6a6258") if i % 2 == 0 else Color("#3a3632"), r = 2.5 + randf() * 2, g = 0.0, h = 1.0 + randf() * 2, rise = 2.0 - i % 3 * 2.5})
	for i in (6 if big else 2):
		if pt.size() < 390:
			pt.append({x = k.x + (randf() - 0.5) * ext, y = k.y + (randf() - 0.5) * ext, vx = (randf() - 0.5) * 20, vy = (randf() - 0.5) * 20, t = 0.0, d = 1.8 + randf(), c = Color("#5a554e"), r = ext * 0.25 + 4, g = ext * 0.3 + 4, h = 0.8, rise = 1.2})
	if scorch.size() > 50:
		scorch.pop_front()
	scorch.append({x = k.x, y = k.y, r = ext * 0.9})
	if big:
		shake = minf(18.0, shake + 6.0)
		Synth.noise(0.9, 0.24, 240)
		Synth.beep(55, 0.7, "sawtooth", 0.05, -15)
	else:
		Synth.noise(0.3, 0.14, 700)
	WG.build_wreck(n, k)
	match k.kind:
		"bld":
			## 건물은 낮은 잔해로 남는다: 지나갈 수는 없지만 탄환과 시야는 통한다
			k.dead = false
			k.kind = "rubble"
			k.h = 8.0
			k.hw *= 0.82
			k.hh *= 0.82
		"car":
			## 연료 탱크 유폭
			var cx: float = k.x
			var cy: float = k.y
			later(0.18, func(): explode(cx, cy, 58, 120, {fixed = true, ffCap = 22.0}))


func enemy_blast(x: float, y: float, r: float, d: float) -> void:
	fx.append({x = x, y = y, r = r, t = 0.0, d = 0.4})
	shake = minf(12.0, shake + 5)
	Synth.noise(0.35, 0.18, 600)
	## 적 포탄은 사람 기준 피해라 구조물에는 크게 먹인다
	blast_props(x, y, r, d * 8.0)
	if Vector2(p.x - x, p.y - y).length() < r:
		hurt(d)
	for a in squad + drones:
		if Vector2(a.x - x, a.y - y).length() < r:
			ally_hurt(a, d)


## 부대원·드론이 맞았다. 체력이 다하면 쓰러지고(드론은 격추) 대기 시간 뒤 복귀한다
func ally_hurt(a: Dictionary, d: float) -> void:
	if a.down > 0 or over:
		return
	a.hp -= d * (1.0 + 0.4 * lv())
	if a.hp > 0:
		return
	var man: bool = a.has("role")
	a.down = (SQ_BACK_ELITE if a.elite else SQ_BACK) if man else DRONE_BACK
	floater(a.x, a.y, ALLY_NAME[a.role if man else a.k] + (" 쓰러짐" if man else " 격추"), Color("#ff8a7a"), 14)
	if man:
		a.hackT = 0.0
		puff(a.x, a.y, Color("#5a1a14"), 6, 110.0)
		Synth.beep(260, 0.25, "sawtooth", 0.04, -120)
	else:
		fx.append({x = a.x, y = a.y, r = 20.0, t = 0.0, d = 0.25, h = 1.6})
		puff(a.x, a.y, Color("#3a3632"), 6, 130.0)
		Synth.noise(0.2, 0.1, 900)


## 재투입 지점: 쓰러진 자리 둘레에서 가장 가까운 적까지 SAFE 이상 떨어진 곳 중 제일 가까운 데.
## 그런 곳이 없으면 적에게서 가장 먼 후보를 쓴다
func safe_drop(x: float, y: float) -> Vector2:
	const SAFE := 520.0
	var best := Vector2(x, y)
	var best_d := -1.0
	for ring in [320.0, 480.0, 640.0, 800.0, 1000.0]:
		for i in 16:
			var a: float = i / 16.0 * TAU + ring * 0.01
			var cx: float = x + cos(a) * ring
			var cy: float = y + sin(a) * ring
			if cx < 60 or cy < 60 or cx > WORLD - 60 or cy > WORLD - 60 or blocked(cx, cy):
				continue
			var md := 1e9
			for e in en:
				md = minf(md, Vector2(e.x - cx, e.y - cy).length())
			if md > best_d:
				best_d = md
				best = Vector2(cx, cy)
		if best_d >= SAFE:
			break
	return best


func hurt(d: float) -> void:
	if p.shieldT > 0 or p.inv > 0 or over:
		return
	p.hp -= d * (1.0 + 0.4 * lv())
	p.hurtT = 0.2
	if p.hp <= 0:
		if p.lives > 0:
			p.lives -= 1
			p.hp = p.maxhp
			## 적이 없는 쪽을 골라 낙하산으로 다시 내려온다. 무적은 없다: 들키면 그대로 공격받는다
			p.dropT = DROP
			p.inv = 0.0
			banner("증원 강하")
			flash = 0.3
			explode(p.x, p.y, 170, 400, {noFF = true, fixed = true, kb = 400.0})
			var sp: Vector2 = safe_drop(p.x, p.y)
			p.x = sp.x
			p.y = sp.y
		else:
			end_game(false)


func pick_from(x: float, y: float, range: float, min_d: float):
	var b = null
	var bs = -1
	for e in en:
		var d = Vector2(e.x - x, e.y - y).length()
		if d > range or d < min_d:
			continue
		var c = 4 if e.T.has("armor") else 1
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
						## 길리 저격수: 조준 중이거나 쏜 직후(드러남), 또는 아주 가까울 때만 표적이 된다
						if e.type == "sn" and e.rev <= 0 and e.aimT <= 0 and d > 90:
							continue
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
			if not is_same(f, e) and f.st != "alert" and f.st != "call" and Vector2(f.x - e.x, f.y - e.y).length() < 320:
				alert_e(f, true)
	if rcall == null and rcd <= 0 and empT <= 0 and not e.T.has("armor") and e.type != "dr" and ext.state != "wait" and ext.state != "land":
		e.st = "call"
		e.callT = lerpf(3.4, 2.0, lv())
		e.callMax = e.callT
		rcall = e
		banner("적이 증원을 요청 중! 무전병을 처치하라")
		Synth.beep(300, 0.3, "sawtooth", 0.05, 200)


## 그 스테이지의 주력 기갑: 초반은 경전차, 3단계부터 전차
func heavy() -> String:
	return "lt" if stage <= 2 else "tk"


## 증원에 섞여 오는 기갑 편성. 스테이지가 오를수록 경전차 → 전차 → 자주포 → 미사일 발사대가 차례로 더해지고,
## 같은 스테이지에서도 증원을 여러 번 부를수록(heat) 한 단계씩 앞당겨진다
func reinf_armor() -> Array:
	var tier = clampi((stage + 1) / 2 + (1 if heat >= 3 else 0), 1, 5)
	if stage <= 2 and heat < 2:
		return []
	match tier:
		1: return ["lt"]
		2: return ["lt", "tk"] if heat >= 2 else ["lt"]
		3: return ["lt", "tk", "sp"] if heat >= 2 else ["lt", "tk"]
		4: return ["lt", "tk", "sp", "ml"] if heat >= 2 else ["lt", "tk", "sp"]
		_: return ["lt", "lt", "tk", "sp", "ml"]


func reinforce(c: Dictionary) -> void:
	musicT = 34.0
	rcall = null
	heat += 1
	rcd = (22.0 + heat * 2) / reinf_mul
	## 대규모 증원: 3파에 걸쳐 사방(다섯 방향)에서 포위하듯 몰려온다
	var n = roundi(minf(60, 16 + lv() * 16 + heat * 8) * reinf_mul)
	var a = atan2(c.y - p.y, c.x - p.x)
	var fac_on: bool = map.objs.any(func(o): return o.type == "fac" and not o.done)
	banner("적 증원이 사방에서 몰려온다 (부대 파괴로 병력 감소)" if reinf_mul < 1 else "적 증원이 사방에서 몰려온다!")
	Synth.beep(240, 0.4, "sawtooth", 0.06, -80)
	Synth.beep(180, 0.5, "sawtooth", 0.05, -60, 0.25)
	for wv in 3:
		var m = n / 3 + (n % 3 if wv == 0 else 0)
		var last = wv == 2
		later(1.4 + wv * 1.5, func():
			for i in m:
				if en.size() >= 300:
					break
				var r = randf()
				var dr_ok: bool = heat >= 2 and not no_armor
				var dir = a + (i % 5) * TAU / 5.0 + wv * 0.4 + (randf() - 0.5) * 0.5
				spawn("dr" if dr_ok and r < 0.15 else "ru" if r < 0.6 else "rf" if r < 0.86 else "sh", null, null, dir)
			last_seen = Vector2(p.x, p.y)
			## 포위된 것을 알 수 있게 주변의 적도 전부 플레이어 쪽으로 온다
			for f in en:
				if f.hp > 0 and f.st != "alert" and f.st != "call" and d2(f, p) < SHARE_SUS:
					f.st = "sus"
					f.inv = Vector2(p.x, p.y)
					f.aw = maxf(f.aw, 0.6)
					f.lookT = 0.0
			if no_armor:
				return
			## 기갑 증원: 마지막 파에 스테이지와 증원 횟수에 맞는 편성이 여러 방향에서 들어온다
			if last:
				var arm: Array = reinf_armor()
				for i in arm.size():
					spawn(arm[i], null, null, a + PI + i * TAU / maxf(1.0, arm.size()))
			## 군수공장이 돌아가는 동안에는 증원마다 기갑이 한 대 더 온다
			if wv == 0 and fac_on:
				spawn(heavy(), null, null, a))


## 구역 점령 중 증원 파도: 무전 요청 없이 바로 온다. 적 부대 파괴 시 절반
func _siege_wave() -> void:
	var n = maxi(4, roundi(minf(26, 10 + heat * 3) * reinf_mul))
	siegeN += n
	var a = randf() * TAU
	for i in n:
		if en.size() >= 300:
			break
		var r = randf()
		spawn("dr" if r < 0.15 and not no_armor else "ru" if r < 0.55 else "rf" if r < 0.85 else "sh", null, null, a + (i % 3) * TAU / 3.0 + (randf() - 0.5) * 0.5)
	last_seen = Vector2(p.x, p.y)


## 적이 플레이어를 얼마나 잘 보는지 0~1
func see_p(e: Dictionary, d: float, dx: float, dy: float) -> float:
	var vis: float = e.T.vis
	if d > vis or p.inv > 2:
		return 0.0
	for z in zones:
		if z.k == "smoke" and (Vector2(p.x - z.x, p.y - z.y).length() < z.r or Vector2(e.x - z.x, e.y - z.y).length() < z.r):
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
## kind: "f35"(폭격) / "a10"(기총소사, 조금 느리고 낮게 난다)
func flyby(x: float, y: float, ang: float, t_over: float, big := false, kind := "f35") -> void:
	var v = 420.0 if big else 470.0 if kind == "a10" else 560.0
	var n = AC.jet(big, kind)
	n.scale = Vector3.ONE * (1.15 if big else 1.4)
	dyn.add_child(n)
	jets.append({x = x - cos(ang) * v * t_over, y = y - sin(ang) * v * t_over, vx = cos(ang) * v, vy = sin(ang) * v, ang = ang, life = t_over + 1.4, big = big, alt = 7.0 if big else 4.2 if kind == "a10" else 5.5, node = n})
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
	## 방호 장막·저격·전자전·위성은 하늘로 실어 오는 것이 아니라 방공망에 걸리지 않는다
	if not ["shield", "sniper", "emp", "sat"].has(s.id) and aa_global():
		_intercept(s, T)
		return
	## 교란기 사보타주: 교란기가 살아 있으면 좌표가 흐트러져 지원이 엉뚱한 곳에 떨어진다
	if s.aim != "" and in_jam():
		var ja = randf() * TAU
		var jd = 120.0 + randf() * 200
		T = T.duplicate()
		T.x = clampf(T.x + cos(ja) * jd, 30, WORLD - 30)
		T.y = clampf(T.y + sin(ja) * jd, 30, WORLD - 30)
		T.ang = T.ang + (randf() - 0.5) * 1.6
		x = T.x
		y = T.y
		ca = cos(T.ang)
		sa = sin(T.ang)
		floater(p.x, p.y - 24, "좌표 교란!", Color("#d9a8ff"), 14)
		if not jam_warned:
			jam_warned = true
			banner("교란기가 좌표를 흐트린다. 교란기를 부숴야 지원이 제자리에 떨어진다")
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
			flyby(x, y, T.ang, 0.55, false, "a10")
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
						e.frz = 2.5 if e.T.has("armor") else 4.5
						hit_enemy(e, 40, true)
				fx.append({x = x, y = y, r = r, t = 0.0, d = 0.5, c = Color.WHITE})
				flash = 0.35
				Synth.noise(0.3, 0.25, 3000)
				shake = 8.0)
		"hmg":
			beacon(x, y, 45, 0.8, "#f2c21b", true)
			later(0.8, func():
				explode(x, y, 48, 90, {noFF = true})
				var n = AC.hmg()
				n.position = p3(x, y)
				dyn.add_child(n)
				turrets.append({x = x, y = y, life = 25.0, max = 25.0, fireT = 0.0, aim = p.aim, k = "hmg", node = n})
				floater(x, y, "올라타면 사격", Color("#f2c21b"), 14))
		"missiles":
			## 순항 미사일: 맵 밖 먼 곳에서 4발이 날아와 체력 높은 적을 쫓는다
			var tg = en.filter(func(e): return e.hp > 0 and d2(e, p) < 700)
			tg.sort_custom(func(a, b): return a.hp > b.hp)
			var from = randf() * TAU
			for i in 4:
				var e = tg[i % tg.size()] if tg.size() else null
				var tx: float = e.x if e != null else p.x + p.fx * 220 + (i - 1.5) * 50
				var ty: float = e.y if e != null else p.y + p.fy * 220
				var n = Node3D.new()
				MK.inst(n, MK.cached("cruise", func():
					var k = MK.new()
					k.cyl(0.17, 0.17, 1.7, Vector3.ZERO, "#c9ced4", "x", 10)
					k.lathe([Vector2(0.17, 0.0), Vector2(0.12, 0.25), Vector2(0.0, 0.5)], Vector3(0.85, 0, 0), "#8d959c", Vector3(0, 0, -PI / 2), 10)
					k.box(Vector3(0.45, 0.04, 1.7), Vector3(0.05, 0.02, 0), "#aab0b6", Vector3.ZERO, 0.015)
					for sz in [-1.0, 1.0]:
						k.box(Vector3(0.3, 0.03, 0.4), Vector3(-0.72, 0, sz * 0.3), "#8d959c")
					k.box(Vector3(0.3, 0.42, 0.03), Vector3(-0.72, 0.2, 0), "#8d959c")
					k.box(Vector3(0.5, 0.14, 0.2), Vector3(-0.3, -0.2, 0), "#5a6068", Vector3.ZERO, 0.04)
					k.box(Vector3(0.2, 0.345, 0.345), Vector3(0.3, 0, 0), "#a8322a")
					return k.commit()))
				ML.no_shadow(ML.sph(n, 0.2, "#ffb046", Vector3(-1.0, 0, 0), Vector3(2.2, 1, 1), ML.add_mat("#ffb046", 0.9), 8))
				n.visible = false
				dyn.add_child(n)
				var lat = (i - 1.5) * 70.0
				mis.append({x = tx - cos(from) * 1350 - sin(from) * lat, y = ty - sin(from) * 1350 + cos(from) * lat, a = from, tg = e, tx = tx, ty = ty, life = 6.0, d = i * 0.28, alt = 15.0, node = n})
			Synth.beep(120, 1.6, "sawtooth", 0.035, 160)
			later(1.2, func(): Synth.noise(1.4, 0.14, 700))
		"sniper":
			snipe = {t = 15.0, ft = 0.5, a = randf() * TAU}
			banner("저격 지원 개시")
			Synth.beep(980, 0.1, "sine", 0.04)
		"sat":
			satT = 30.0
			banner("위성 정찰: 30초간 모든 적이 지도에 표시된다")
			Synth.beep(1400, 0.08, "sine", 0.04); Synth.beep(1700, 0.2, "sine", 0.04, 0.0, 0.1)
		"emp":
			empT = 20.0
			banner("전자전 개시: 20초간 적 통신·기갑 마비")
			if rcall != null:
				rcall.st = "alert"
				rcall = null
			for e in en:
				if e.T.has("boss"):
					## 보스는 잠깐만 멈춘다
					e.frz = maxf(e.frz, 3.0)
				elif e.type == "dr" or e.T.has("armor"):
					e.frz = maxf(e.frz, 20.0)
					e.aimT = 0.0
			fx.append({x = p.x, y = p.y, r = 520.0, t = 0.0, d = 0.9, c = Color("#7fb8ff")})
			flash = 0.15
			Synth.noise(0.6, 0.2, 4000)
			Synth.beep(1800, 0.5, "sawtooth", 0.04, -1500)
		"smoke":
			beacon(x, y, 150, 0.9, "#c8ccd0")
			later(0.9, func():
				zones.append({x = x, y = y, r = 150.0, life = 12.0, k = "smoke"})
				for i in 3:
					var a = i / 3.0 * TAU
					fx.append({x = x + cos(a) * 60, y = y + sin(a) * 60, r = 30.0, t = 0.0, d = 0.3, c = Color("#d8dce0")})
				Synth.noise(0.6, 0.14, 500))
		"naval":
			beacon(x, y, 150 * B, 3.0, "#ff4d4d")
			banner("함포 사격 요청. 탄착 지점에서 벗어나라")
			Synth.beep(60, 2.4, "sawtooth", 0.04, 20, 0.6)
			for i in 3:
				var a = randf() * TAU
				var bx = x + cos(a) * 55 * (1 if i > 0 else 0)
				var by = y + sin(a) * 55 * (1 if i > 0 else 0)
				warn(bx, by, 150 * B, 3.0 + i * 0.9)
				later(3.0 + i * 0.9, func():
					flash = 0.3
					hs = 0.06
					explode(bx, by, 150, 700, {ffCap = 60.0, kb = 420.0})
					shake = 22.0
					fx.append({x = bx, y = by, r = 190.0, t = 0.0, d = 0.6, c = Color("#ffd9a0")}))
		"apache":
			_spawn_gs()
		"ltank", "tank":
			var ak = "lt" if s.id == "ltank" else "tk"
			beacon(x, y, 48, 1.2, "#4fa3d9", true)
			later(1.2, func(): _spawn_av(ak, x, y))
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


## 방공망에 걸린 지원요청: 전투기는 요격 미사일을 피해 플레어를 뿌리며 이탈하고, 그 밖의 것은 공중에서 격추된다
func _intercept(s: Dictionary, T: Dictionary) -> void:
	var aa = _aa_src()
	if aa == null:
		return
	if aa.has("known"):
		aa.known = true
	banner("방공망에 요격당했다! 방공포를 파괴해야 지원요청이 닿는다")
	floater(p.x, p.y, s.name + " 요격됨", Color("#ff6a5a"), 15)
	for i in 3:
		Synth.beep(1250, 0.07, "square", 0.04, 0.0, i * 0.13)
	if ["air", "strafe", "napalm", "carpet"].has(s.id):
		flyby(T.x, T.y, T.ang, 0.95, s.id == "carpet", "a10" if s.id == "strafe" else "f35")
		var j: Dictionary = jets[jets.size() - 1]
		j.evade = 0.5
		j.dir = 1.0 if randf() < 0.5 else -1.0
		j.life += 1.2
		_sam(aa.x, aa.y, j.x + j.vx * 0.85, j.y + j.vy * 0.85, j.alt, 0.85)
		_sam(aa.x, aa.y, j.x + j.vx * 1.05 + 50, j.y + j.vy * 1.05 - 40, j.alt + 1.5, 1.1)
	else:
		_sam(aa.x, aa.y, T.x, T.y, 11.0, 0.8)


func _sam(x0: float, y0: float, x1: float, y1: float, alt: float, dur: float) -> void:
	var n = Node3D.new()
	MK.inst(n, MK.cached("sam", func():
		var k = MK.new()
		k.cyl(0.09, 0.09, 1.3, Vector3.ZERO, "#e4e6e2", "x", 8)
		k.lathe([Vector2(0.09, 0.0), Vector2(0.0, 0.35)], Vector3(0.65, 0, 0), "#b8322a", Vector3(0, 0, -PI / 2), 8)
		for a in 4:
			k.box(Vector3(0.3, 0.26, 0.02), Vector3(-0.5, 0, 0), "#8d959c", Vector3(a * PI / 2 + PI / 4, 0, 0))
		return k.commit()))
	ML.no_shadow(ML.sph(n, 0.16, "#ffb046", Vector3(-0.85, 0, 0), Vector3(2.4, 1, 1), ML.add_mat("#ffb046", 0.95), 8))
	dyn.add_child(n)
	sams.append({x0 = x0, y0 = y0, x1 = x1, y1 = y1, alt = alt, t = 0.0, d = dur, node = n})
	fx.append({x = x0, y = y0, r = 22.0, t = 0.0, d = 0.25})
	for i in 6:
		if pt.size() < 390:
			pt.append({x = x0, y = y0, vx = (randf() - 0.5) * 80, vy = (randf() - 0.5) * 80, t = 0.0, d = 1.2, c = Color("#8a857c"), r = 5.0, g = 6.0, h = 1.5, rise = 1.0})
	Synth.noise(0.5, 0.14, 1800)
	Synth.beep(300, 0.6, "sawtooth", 0.04, 700)


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
		"jam":
			radar = true
			banner("교란기 파괴: 미니맵 복구, 주변 적이 지도에 표시된다")
		"fac":
			no_armor = true
			banner("군수공장 파괴: 적 증원에서 전차·드론 제외")
		"aa":
			cd_mul = 0.75
			for s in strats:
				s.t *= 0.75
			recalc()
			banner("방공포 파괴: 이제 지원요청이 닿는다. 재사용 대기 25% 감소" if stage >= 3 else "방공포 파괴: 지원요청 재사용 대기 25% 감소")
		_:
			var ms: Array = map.objs.filter(func(q): return q.type == "term" or q.type == "boss")
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
	if p.xp >= p.next and pause == "" and not over and ext.state != "leave":
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


## 진화 순간: 짧은 알림과 효과음만. 손맛은 진화한 무기 쪽에서 낸다
func _evolve_fx(ev: Dictionary) -> void:
	evo_col = Color(EVO_COL.get(ev.id, "#f2c21b"))
	evo_name = ev.n
	evoT = EVO_DUR
	flash = 0.1
	shake = 5.0
	_vib(60)
	fx.append({x = p.x, y = p.y, r = 90.0, t = 0.0, d = 0.4, c = evo_col})
	for i in 14:
		if pt.size() >= 400:
			break
		var a = randf() * TAU
		var sp = 90.0 + randf() * 120
		pt.append({x = p.x, y = p.y, vx = cos(a) * sp, vy = sin(a) * sp, t = 0.0, d = 0.5 + randf() * 0.3, c = evo_col, r = 2.5, g = 0.0, h = 0.8, rise = 3.0, glow = true})
	var notes = [523.0, 784.0, 1047.0]
	for i in notes.size():
		Synth.beep(notes[i], 0.3 if i == notes.size() - 1 else 0.1, "square", 0.05, 0.0, i * 0.08)
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
	## 처치: 색 충격링 + 파편 + 화면 흔들림. 터지면서 옆의 적까지 다쳐 연쇄로 쓰러진다
	fx.append({x = e.x, y = e.y, r = 40.0 + e.r, t = 0.0, d = 0.28, c = wc})
	area_dmg(e.x, e.y, 40.0, 16.0 * p.m.dmg)
	puff(e.x, e.y, wc, 8, 220)
	puff(e.x, e.y, Color("#5a1a14"), 5, 140)
	shake = minf(14.0, shake + 2.0)
	if t - _evo_snd > 0.06:
		_evo_snd = t
		Synth.beep(220, 0.1, "square", 0.04, -140)
		Synth.noise(0.12, 0.08, 1400)


## ---------- 공격헬기 (지원요청) ----------
const GS_LIFE := 25.0
func _spawn_gs() -> void:
	if gs != null:
		## 이미 떠 있으면 체공 시간만 다시 채운다
		gs.life = GS_LIFE
		gs.erase("leave")
		return
	var n = AC.apache()
	n.scale = Vector3.ONE * 0.62
	dyn.add_child(n)
	gs = {a = randf() * TAU, x = p.x, y = p.y - 400, fireT = 0.0, rkT = 2.5, face = 0.0, node = n, nT = -9.0, life = GS_LIFE}
	banner("공격헬기 도착")
	Synth.beep(90, 1.2, "sawtooth", 0.05, 30)


func _update_gs(dt: float) -> void:
	if gs == null:
		return
	if gs.has("leave"):
		## 체공 시간이 끝나 기수를 돌려 떠난다
		gs.leave -= dt
		gs.x += cos(gs.face) * 260 * dt
		gs.y += sin(gs.face) * 260 * dt
		if gs.leave <= 0:
			gs.node.queue_free()
			gs = null
		return
	if gs.has("doom"):
		## 요격 미사일이 날아오는 중: 플레어를 뿌리며 버티다 격추된다
		gs.doom -= dt
		gs.a += dt * 2.4
		gs.x += cos(gs.a) * 90 * dt
		gs.y += sin(gs.a) * 90 * dt
		if pt.size() < 390:
			pt.append({x = gs.x, y = gs.y, vx = (randf() - 0.5) * 160, vy = (randf() - 0.5) * 160, t = 0.0, d = 0.9, c = Color("#fff0b0"), r = 3.0, g = 0.0, h = 7.0, rise = -3.0, glow = true})
		if gs.doom <= 0:
			fx.append({x = gs.x, y = gs.y, r = 60.0, t = 0.0, d = 0.5, h = 7.5})
			for q in 10:
				if pt.size() < 390:
					var da = randf() * TAU
					pt.append({x = gs.x, y = gs.y, vx = cos(da) * (60 + randf() * 120), vy = sin(da) * (60 + randf() * 120), t = 0.0, d = 1.2, c = Color("#3a3632"), r = 3.0, g = 5.0, h = 7.5, rise = -5.0})
			shake = minf(14.0, shake + 6.0)
			Synth.noise(0.6, 0.24, 300)
			gs.node.queue_free()
			gs = null
			banner("공격헬기 격추. 방공포를 부숴야 다시 부를 수 있다")
		return
	gs.life -= dt
	if gs.life <= 0:
		gs.leave = 3.5
		floater(p.x, p.y, "공격헬기 이탈", Color("#f2c21b"), 14)
		return
	if aa_global():
		## 방공망에 걸렸다
		var src = _aa_src()
		if src != null:
			if src.has("known"):
				src.known = true
			_sam(src.x, src.y, gs.x, gs.y, 7.5, 0.9)
			_sam(src.x, src.y, gs.x + 40, gs.y - 30, 8.5, 1.1)
		gs.doom = 0.9
		banner("공격헬기가 방공망에 걸렸다!")
		for i in 3:
			Synth.beep(1250, 0.07, "square", 0.04, 0.0, i * 0.13)
		return
	gs.a += dt * 0.85
	var k = minf(1.0, dt * 2.2)
	gs.x = lerpf(gs.x, p.x + cos(gs.a) * 130, k)
	gs.y = lerpf(gs.y, p.y + sin(gs.a) * 130, k)
	var tg = nearest(gs.x, gs.y, 430, true, false)
	if tg == null:
		gs.face = turn_to(gs.face, gs.a + PI / 2, dt * 2.0)
		return
	var ta = atan2(tg.y - gs.y, tg.x - gs.x)
	gs.face = turn_to(gs.face, ta, dt * 6.0)
	## 기관포
	gs.fireT -= dt
	if gs.fireT <= 0:
		gs.fireT = 0.085
		shoot(gs.x + cos(ta) * 18, gs.y + sin(ta) * 18, ta + (randf() - 0.5) * 0.08, {speed = 700.0, range = 450.0, kb = 18.0}, 16 * p.m.dmg, 1, {evo = true})
		make_noise(gs.x, gs.y, 260, gs)
		if t - last_shot > 0.07:
			last_shot = t
			Synth.noise(0.05, 0.05, 1500)
	## 로켓 4연발: 적이 몰린 곳으로
	gs.rkT -= dt
	if gs.rkT <= 0:
		var rt2 = pick_from(gs.x, gs.y, 430, 0)
		if rt2 == null:
			gs.rkT = 0.5
			return
		gs.rkT = 4.0
		var hx: float = gs.x
		var hy: float = gs.y
		for i in 4:
			var rx: float = rt2.x + randf_range(-34, 34)
			var ry: float = rt2.y + randf_range(-34, 34)
			warn(rx, ry, 46 * p.m.blast, 0.4 + i * 0.12, Color("#ffb060"))
			later(0.4 + i * 0.12, func():
				beams.append({x0 = hx, y0 = hy, x1 = rx, y1 = ry, t = 0.0, d = 0.2, w = 0.4, c = Color("#ffb060")})
				explode(rx, ry, 46, 110, {noFF = true}))
		Synth.noise(0.5, 0.16, 800)


## ---------- 부대원 ----------
## 뒤를 따르며 교전한다. 플레이어 길을 막지 않게 가까이 오면 밀려난다(플레이어 쪽은 부대원에게 걸리지 않는다).
## 적은 부대원을 노리지 않는다. 은신 중에는 플레이어 사거리 밖의 적에게 먼저 쏘지 않는다
func _update_squad(dt: float) -> void:
	if squad.is_empty():
		breakout = null
		return
	var elite: bool = p.evo.has("squad")
	## 포위 판정: 300 안의 교전 중인 적이 8방향 가운데 6방향 이상을 메우면, 가장 얇은 쪽을 탈출로로 잡는다
	breakT -= dt
	if breakT <= 0:
		breakT = 0.4
		var sec = [0, 0, 0, 0, 0, 0, 0, 0]
		var n = 0
		for e in en:
			if e.hp <= 0 or (e.st != "alert" and e.st != "call"):
				continue
			var dx: float = e.x - p.x
			var dy: float = e.y - p.y
			if dx * dx + dy * dy > 300.0 * 300.0:
				continue
			sec[int(fposmod(atan2(dy, dx), TAU) / TAU * 8) % 8] += 3 if e.T.has("armor") else 1
			n += 1
		if n >= 8 and sec.filter(func(v): return v > 0).size() >= 6:
			var bi = 0
			var bv = 1e9
			for i in 8:
				var v: float = sec[i] * 2 + sec[(i + 1) % 8] + sec[(i + 7) % 8]
				## 이미 잡아 둔 방향은 조금 봐줘서 탈출로가 이리저리 튀지 않게 한다
				if breakout != null and absf(ang_d((i + 0.5) * TAU / 8, breakout.a)) < 0.1:
					v -= 2.5
				if v < bv:
					bv = v
					bi = i
			if breakout == null:
				floater(p.x, p.y - 30, "분대: 탈출로를 연다!", Color("#7fe0a0"), 16)
				Synth.beep(880, 0.08, "square", 0.04); Synth.beep(1175, 0.14, "square", 0.04, 0.0, 0.09)
			breakout = {a = (bi + 0.5) * TAU / 8, t = 2.0}
		elif breakout != null:
			breakout.t -= 0.4
			if breakout.t <= 0:
				breakout = null
	## 공병이 대신 넣어 줄 부호 (단말기·통신탑. 탈출 SOS는 플레이어가 직접 친다)
	var ctx = ctx_code()
	if ctx != null and not ctx.has("o"):
		ctx = null
	for i in squad.size():
		var m: Dictionary = squad[i]
		if m.down > 0:
			## 쓰러져 있다가 대기 시간이 끝나면 플레이어 곁으로 복귀한다
			m.down -= dt
			if m.down <= 0:
				m.hp = m.maxhp
				m.x = p.x - p.fx * 40 + randf_range(-14, 14)
				m.y = p.y - p.fy * 40 + randf_range(-14, 14)
				puff(m.x, m.y, Color("#b9ab8c"), 6, 80.0)
				floater(m.x, m.y, ALLY_NAME[m.role] + " 복귀", Color("#7fe0a0"), 14)
			continue
		## 자리: 플레이어 뒤쪽 대형. 공병은 해킹할 것이 있으면 그 앞으로 간다
		var sl: Vector2 = SQ_SLOT[i]
		var tx: float = p.x + p.fx * sl.x - p.fy * sl.y
		var ty: float = p.y + p.fy * sl.x + p.fx * sl.y
		var hacking: bool = m.role == "eng" and ctx != null
		if hacking:
			var oa: float = atan2(p.y - ctx.o.y, p.x - ctx.o.x) + 0.7
			tx = ctx.o.x + cos(oa) * ctx.o.r * 0.55
			ty = ctx.o.y + sin(oa) * ctx.o.r * 0.55
		var ddx: float = tx - m.x
		var ddy: float = ty - m.y
		var dd: float = sqrt(ddx * ddx + ddy * ddy)
		if dd > 520:
			## 너무 멀어졌으면(재투입 등) 곁으로 다시 내려온다
			m.x = tx; m.y = ty
			puff(m.x, m.y, Color("#b9ab8c"), 6, 80.0)
			dd = 0.0
		m.mv = dd > 10
		if m.mv:
			var sp: float = minf(128.0 * p.m.spd * 1.25, dd * 5.0) * dt
			m.x += ddx / dd * sp
			m.y += ddy / dd * sp
			if not hacking or dd > 40:
				m.face = turn_to(m.face, atan2(ddy, ddx), dt * 10)
		## 플레이어에게 밀려난다 + 부대원끼리 겹치지 않는다
		var px: float = m.x - p.x
		var py: float = m.y - p.y
		var pd: float = sqrt(px * px + py * py)
		if pd < 26.0:
			if pd < 0.01:
				px = -p.fy; py = p.fx; pd = 1.0
			m.x = p.x + px / pd * 26.0
			m.y = p.y + py / pd * 26.0
		for j in i:
			var o: Dictionary = squad[j]
			if o.down > 0:
				continue
			var sx: float = m.x - o.x
			var sy: float = m.y - o.y
			var sd: float = sqrt(sx * sx + sy * sy)
			if sd < 20.0 and sd > 0.01:
				var push: float = (20.0 - sd) * 0.5
				m.x += sx / sd * push; m.y += sy / sd * push
				o.x -= sx / sd * push; o.y -= sy / sd * push
		rock_push(m)
		## 공병: 모스 부호 대행
		if m.role == "eng":
			if ctx == null or ctx.code != m.hackC:
				m.hackT = 0.0
				m.hackC = ctx.code if ctx != null else ""
			elif d2(m, ctx.o) < ctx.o.r:
				m.face = turn_to(m.face, atan2(ctx.o.y - m.y, ctx.o.x - m.x), dt * 8)
				m.hackT += dt
				if m.hackT >= sq_hack_need():
					m.hackT = 0.0
					m.hackC = ""
					floater(m.x, m.y, "공병 ▸ 부호 송신", Color("#62d0f0"), 15)
					var bl = 0.0
					for ch in ctx.code:
						Synth.beep(1250, 0.04 if ch == "." else 0.11, "sine", 0.035, 0.0, bl)
						bl += 0.07 if ch == "." else 0.15
					fire_code({o = ctx.o})
					ctx = null
		## 의무병
		if m.role == "med" and p.hp < p.maxhp and not over:
			p.hp = minf(p.maxhp, p.hp + (2.5 if elite else 1.5) * dt)
		## 사격
		m.fireT -= dt
		if m.fireT > 0 or p.dropT > 0:
			continue
		var tg = null
		if breakout != null:
			tg = _break_target(m)
		if tg == null:
			tg = nearest(m.x, m.y, 250, true, true)
			if tg != null and alertN <= 0 and d2(tg, p) > p.w.range:
				tg = null
		if tg == null:
			m.fireT = 0.12
			continue
		var fa: float = atan2(tg.y - m.y, tg.x - m.x)
		m.face = fa
		var sup: bool = m.role == "sup"
		m.fireT = (0.1 if sup else 0.24 if m.role == "rf" else 0.34) * (0.55 if breakout != null else 1.0)
		var mz: Vector2 = muzzle(m.x, m.y, fa, 20.0)
		shoot(mz.x, mz.y, fa + (randf() - 0.5) * (0.16 if sup else 0.06), SQ_W, (5.0 if sup else 8.0) * (1.6 if elite else 1.0) * p.m.dmg, 1 if elite else 0)
		make_noise(m.x, m.y, 180, m)
		if t - last_shot > 0.07:
			last_shot = t
			Synth.noise(0.05, 0.035, 2000)


func sq_hack_need() -> float:
	return 3.0 if p.evo.has("squad") else 6.0


## 탈출로 방향(±1.1 rad) 안에서 플레이어에게 가장 가까운 적. 부대원에게서 사선이 통해야 한다
func _break_target(m: Dictionary):
	var b = null
	var bd = 340.0
	for e in en:
		if e.hp <= 0:
			continue
		var d: float = d2(e, p)
		if d >= bd or absf(ang_d(atan2(e.y - p.y, e.x - p.x), breakout.a)) > 1.1:
			continue
		if not los(m.x, m.y, e.x, e.y):
			continue
		bd = d
		b = e
	return b


## ---------- 아군 기갑 (지원요청) ----------
## 투하된 뒤 플레이어를 따라다니며 싸우다가 시간이 다 되면 이탈한다. 플레이어 길은 막지 않고, 적은 노리지 않는다
func _spawn_av(k: String, x: float, y: float) -> void:
	explode(x, y, 48, 90, {noFF = true})
	var n = AC.tank(true) if k == "tk" else AC.ltank(true)
	dyn.add_child(n)
	avs.append({k = k, x = x, y = y, r = 24.0 if k == "tk" else 20.0, ha = p.face, ta = p.face, fireT = 1.0, mgT = 0.5, burst = 0, rec = 0.0, life = 35.0 if k == "tk" else 30.0, node = n, nT = -9.0})
	banner("아군 전차 도착" if k == "tk" else "아군 경전차 도착")
	Synth.beep(70, 0.9, "sawtooth", 0.05, 20)


func _update_avs(dt: float) -> void:
	for i in range(avs.size() - 1, -1, -1):
		var av: Dictionary = avs[i]
		av.life -= dt
		av.rec = maxf(0.0, av.rec - dt * 3.0)
		if av.life <= 0:
			floater(av.x, av.y, "전차 이탈", Color("#f2c21b"), 14)
			puff(av.x, av.y, Color("#8a857c"), 12, 120.0)
			av.node.queue_free()
			avs.remove_at(i)
			continue
		var tk: bool = av.k == "tk"
		## 이동: 플레이어에게서 90 넘게 떨어지면 따라붙는다
		var dx: float = p.x - av.x
		var dy: float = p.y - av.y
		var dd: float = sqrt(dx * dx + dy * dy)
		if dd > 90:
			var ma: float = atan2(dy, dx)
			av.ha = turn_to(av.ha, ma, dt * (1.6 if tk else 2.6))
			if absf(ang_d(ma, av.ha)) < 0.6:
				var sp: float = minf((70.0 if tk else 105.0), (dd - 80) * 3.0) * dt
				av.x += cos(av.ha) * sp
				av.y += sin(av.ha) * sp
		## 플레이어와 겹치면 전차가 비켜난다
		elif dd < av.r + 16 and dd > 0.01:
			av.x -= dx / dd * 60 * dt
			av.y -= dy / dd * 60 * dt
		rock_push(av)
		## 주포 표적: 전차는 기갑 우선, 없으면 적이 뭉친 곳. 경전차는 가장 가까운 적
		var tg = null
		if tk:
			var bd = 430.0
			for e in en:
				if e.hp > 0 and e.T.has("armor") and d2(e, av) < bd and (e.st == "alert" or e.st == "call" or alertN > 0):
					bd = d2(e, av)
					tg = e
			if tg == null and alertN > 0:
				tg = pick_from(av.x, av.y, 400, 70)
		var near_e = nearest(av.x, av.y, 300, true, true)
		if near_e != null and alertN <= 0 and d2(near_e, p) > p.w.range:
			near_e = null
		if tg == null:
			tg = near_e
		if tg == null:
			av.ta = turn_to(av.ta, av.ha, dt * 2.0)
			continue
		var ta: float = atan2(tg.y - av.y, tg.x - av.x)
		av.ta = turn_to(av.ta, ta, dt * (2.4 if tk else 5.0))
		var on: bool = absf(ang_d(ta, av.ta)) < 0.12
		av.fireT -= dt
		av.mgT -= dt
		if tk:
			## 주포: 직사 한 발이 크게 터진다
			if av.fireT <= 0 and on:
				av.fireT = 2.6
				av.rec = 1.0
				var mz: Vector2 = muzzle(av.x, av.y, av.ta, 62.0, 0.0)
				var hx: float = tg.x
				var hy: float = tg.y
				beams.append({x0 = mz.x, y0 = mz.y, x1 = hx, y1 = hy, t = 0.0, d = 0.14, w = 0.35, c = Color("#ffc070")})
				fx.append({x = mz.x, y = mz.y, r = 26.0, t = 0.0, d = 0.18, c = Color("#ffd9a0")})
				explode(hx, hy, 62, 300, {noFF = true})
				shake = minf(14.0, shake + 4.0)
				make_noise(av.x, av.y, 420, av)
				Synth.noise(0.35, 0.22, 260)
				Synth.beep(70, 0.25, "sawtooth", 0.06, -30)
			## 동축 기관총
			if av.mgT <= 0 and near_e != null:
				av.mgT = 0.12
				var ga: float = atan2(near_e.y - av.y, near_e.x - av.x)
				var gz: Vector2 = muzzle(av.x, av.y, ga, 30.0, 6.0)
				shoot(gz.x, gz.y, ga + (randf() - 0.5) * 0.09, SQ_W, 9 * p.m.dmg, 0, {h = 1.5})
		elif on:
			## 기관포 3점사 (작렬탄)
			if av.burst > 0 and av.mgT <= 0:
				av.burst -= 1
				av.mgT = 0.1
				av.rec = 0.5
				var cz: Vector2 = muzzle(av.x, av.y, av.ta, 44.0, 0.0)
				shoot(cz.x, cz.y, av.ta + (randf() - 0.5) * 0.05, {speed = 620.0, range = 340.0, kb = 30.0}, 30 * p.m.dmg, 1, {h = 1.1, boom_s = true, evo = true})
				make_noise(av.x, av.y, 300, av)
				Synth.noise(0.07, 0.1, 900)
			elif av.burst <= 0 and av.fireT <= 0:
				av.fireT = 0.9
				av.burst = 3


## ---------- 드론 편대 ----------
func _update_drones(dt: float) -> void:
	var lvl: int = p.up.get("drone", 0)
	var swarm: bool = p.evo.has("drone")
	for i in range(drones.size() - 1, -1, -1):
		var d: Dictionary = drones[i]
		d.a += dt * 2.2
		if d.down > 0:
			## 격추된 드론은 대기 시간 뒤 새 기체가 온다
			d.down -= dt
			if d.down <= 0:
				d.hp = d.maxhp
				d.ammo = 24
				floater(p.x, p.y - 20, ALLY_NAME[d.k] + " 복귀", Color("#7fe0a0"), 13)
			continue
		var orb: float = 34.0 if d.k == "gun" else 48.0
		d.x = p.x + cos(d.a) * orb
		d.y = p.y + sin(d.a) * orb
		d.fireT -= dt
		if d.fireT > 0:
			continue
		match d.k:
			"gun":
				## 24발을 쏘면 1.6초 재장전
				if d.ammo <= 0:
					d.ammo = 24
				var tg = nearest(d.x, d.y, 230, true, true)
				if tg == null:
					d.fireT = 0.1
					continue
				d.ammo -= 1
				d.fireT = 1.6 if d.ammo <= 0 else 0.2
				make_noise(d.x, d.y, 140, d)
				shoot(d.x, d.y, atan2(tg.y - d.y, tg.x - d.x), DW, (7 + 2 * lvl) * p.m.dmg, 0)
			"flame":
				var tg = nearest(d.x, d.y, 120, false, true)
				if tg == null:
					d.fireT = 0.15
					continue
				d.fireT = 0.12
				var fa: float = atan2(tg.y - d.y, tg.x - d.x)
				make_noise(d.x, d.y, 110, d)
				for e in en:
					if e.hp > 0 and d2(e, d) < 125 + e.r and absf(ang_d(atan2(e.y - d.y, e.x - d.x), fa)) < 0.42:
						hit_enemy(e, (2.2 + 0.5 * lvl) * p.m.dmg)
						e.burn = maxf(e.burn, 2.5)
				for j in 2:
					if pt.size() < 390:
						var pa: float = fa + (randf() - 0.5) * 0.5
						var ps: float = 240.0 + randf() * 120
						pt.append({x = d.x, y = d.y, vx = cos(pa) * ps, vy = sin(pa) * ps, t = 0.0, d = 0.38, c = Color("#ff8a2a") if j == 0 else Color("#ffd060"), r = 3.2, g = 0.0, h = 1.4, glow = true})
			"arc":
				## 가까운 적에서 시작해 옆의 적으로 세 번까지 옮겨 붙는다
				var cur = nearest(d.x, d.y, 180, false, true)
				if cur == null:
					d.fireT = 0.2
					continue
				d.fireT = 1.5
				var fx0: float = d.x
				var fy0: float = d.y
				var done: Array = []
				for hop in 4:
					hit_enemy(cur, 20 + 6 * lvl, true)
					cur.frz = maxf(cur.frz, 0.45)
					arcs.append({x1 = fx0, y1 = fy0, x2 = cur.x, y2 = cur.y, t = 0.16})
					done.append(cur.uid)
					fx0 = cur.x
					fy0 = cur.y
					var nx = null
					var nd = 110.0
					for e in en:
						if e.hp > 0 and not done.has(e.uid) and d2(e, cur) < nd:
							nd = d2(e, cur)
							nx = e
					if nx == null:
						break
					cur = nx
				Synth.beep(1800, 0.08, "sawtooth", 0.03, -900)
			"guard":
				## 플레이어 쪽으로 날아오는 적 탄환·포탄을 요격한다 (포탄은 더 오래 쉰다)
				for j in range(eb.size() - 1, -1, -1):
					var b: Dictionary = eb[j]
					if Vector2(b.x - p.x, b.y - p.y).length() > 105 or (b.x - p.x) * b.vx + (b.y - p.y) * b.vy > 0:
						continue
					d.fireT = 0.9 if b.get("shell", false) else 0.3
					beams.append({x0 = d.x, y0 = d.y, x1 = b.x, y1 = b.y, t = 0.0, d = 0.12, w = 0.12, c = Color("#7fe0a0")})
					puff(b.x, b.y, Color("#ffd9a0"), 5 if b.get("shell", false) else 3, 90.0)
					if b.get("shell", false):
						fx.append({x = b.x, y = b.y, r = 22.0, t = 0.0, d = 0.25})
						Synth.noise(0.12, 0.08, 700)
					eb.remove_at(j)
					break
	## 자폭 드론: 대기 시간마다 적이 뭉친 곳으로 출격 (군집 드론은 4기씩)
	if lvl >= 2:
		kamiT -= dt
		if kamiT <= 0:
			var kt = pick_from(p.x, p.y, 340, 0)
			if kt == null or (alertN <= 0 and Vector2(kt.x - p.x, kt.y - p.y).length() > p.w.range):
				kamiT = 0.5
			else:
				kamiT = 9.0
				for i in (4 if swarm else 1):
					var kn = AC.quad("#ffb020", "#4a3a2a")
					kn.scale = Vector3.ONE * 0.8
					dyn.add_child(kn)
					var ka: float = randf() * TAU
					kamis.append({x = p.x + cos(ka) * 20, y = p.y + sin(ka) * 20, a = ka, tx = kt.x + randf_range(-30, 30) * i, ty = kt.y + randf_range(-30, 30) * i, life = 3.0, node = kn})
				Synth.beep(500, 0.25, "sawtooth", 0.035, 500)
	for i in range(kamis.size() - 1, -1, -1):
		var k: Dictionary = kamis[i]
		k.life -= dt
		## 가는 길에 표적 근처의 적을 다시 잡아 쫓는다
		var ke = nearest(k.tx, k.ty, 90, false)
		if ke != null:
			k.tx = ke.x
			k.ty = ke.y
		var kdx: float = k.tx - k.x
		var kdy: float = k.ty - k.y
		var kd: float = sqrt(kdx * kdx + kdy * kdy)
		k.a += clampf(ang_d(atan2(kdy, kdx), k.a), -7.0 * dt, 7.0 * dt)
		k.x += cos(k.a) * 330 * dt
		k.y += sin(k.a) * 330 * dt
		if kd < 18 or k.life <= 0:
			kamis.remove_at(i)
			k.node.queue_free()
			explode(k.x, k.y, 58, 80 + 22 * lvl, {noFF = true})


## ---------- 요청 드론 ----------
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
	if comms.think > 0 or over or in_aa() or aa_global() or ext.state == "land" or aim != null:
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
			"hmg", "smoke", "sat": ok = false
			"sniper": ok = combat and snipe == null
			"emp": ok = combat and (rcall != null or en.any(func(e): return e.T.has("armor") and e.st == "alert"))
			"missiles", "turret", "mortar": ok = combat
			"apache": ok = combat and gs == null
			"ltank", "tank": ok = combat and avs.is_empty()
			_: ok = combat and pick_from(p.x, p.y, 330, 95) != null
		if not ok:
			continue
		comms.cd[s.id] = comms_max(s)
		comms.flash = 0.5
		floater(comms.x, comms.y, "요청 드론 ▸ " + s.name, Color("#62d0f0"), 15)
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
	Synth.music(0)
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
	if stage > 1:
		var db = int(total * 0.25 * (stage - 1))
		rows.append(["스테이지 %d 보너스 x%.2f" % [stage, 1.0 + 0.25 * (stage - 1)], db])
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
			## 다음 부호를 받는 중에는 입력할 것이 없다
			if o.hackT > 0:
				continue
			return {code = o.code, name = "단말기 해킹 %d/3" % (o.hackN + 1), o = o}
		if o.type == "cap" and not o.done and not o.hacked and d2(o, p) < o.r:
			return {code = o.code, name = "통신탑 해킹", o = o}
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
		if hit.o.type == "cap":
			## 통신탑은 해킹이 먼저. 그 뒤 구역 안에서 버텨야 점령된다
			hit.o.hacked = true
			banner("통신탑 해킹 완료. 구역을 지켜 점령하라")
			Synth.beep(660, 0.12); Synth.beep(990, 0.2, "square", 0.05, 0.0, 0.1)
			floater(hit.o.x, hit.o.y, "해킹 완료", Color("#62d0f0"), 16)
		else:
			_hack_step(hit.o)
	elif hit.has("ext"):
		ext.state = "wait"
		ext.t = 30.0
		banner("신호탄 발사! 적 전 병력이 몰려온다. 헬기까지 버텨라")
		Synth.beep(520, 0.5, "sawtooth", 0.06, 400)
		_fire_flare()
		heat = maxi(heat, 3)
		spawn(heavy())
		spawn(heavy())
		make_noise(p.x, p.y, 900)


## 탈출 신호탄: 붉은 불덩이가 솟아올라 상공에 떠 있고, 그 빛을 본 맵 전체의 적이 달려온다
func _fire_flare() -> void:
	if flare_node != null:
		flare_node.queue_free()
	flare_node = Node3D.new()
	var col = Color("#ff3a2a")
	var ball = ML.no_shadow(ML.sph(flare_node, 0.45, col, Vector3.ZERO, Vector3.ONE, ML.mat("#ffd0c0", 6.0, 1.0, true), 10))
	ball.name = "Ball"
	var halo = ML.no_shadow(ML.sph(flare_node, 1.6, col, Vector3.ZERO, Vector3.ONE, ML.add_mat(col, 0.35), 12))
	halo.name = "Halo"
	var l = OmniLight3D.new()
	l.name = "Light"
	l.light_color = Color("#ff5040")
	l.omni_range = 46.0
	l.light_energy = 5.0
	flare_node.add_child(l)
	flare_node.set_meta("x", p.x)
	flare_node.set_meta("y", p.y)
	dyn.add_child(flare_node)
	flareT = 0.0
	flash = 0.12
	shake = maxf(shake, 6.0)
	Synth.noise(0.5, 0.2, 2600)
	Synth.beep(900, 0.7, "sine", 0.05, 900)
	later(1.1, func():
		Synth.noise(0.25, 0.25, 700)
		flash = 0.2)
	for e in en:
		alert_e(e, true)


## 단말기 해킹: 부호를 세 번 넣어야 끝난다. 한 번 넣을 때마다 몇 초 뒤 새 부호가 나오고,
## 두 번째를 넣는 순간 적이 침입을 알아채 증원을 보낸다
const HACK_WAIT := 5.0
func _hack_step(o: Dictionary) -> void:
	o.hackN += 1
	if o.hackN >= 3:
		complete_obj(o)
		return
	o.hackT = HACK_WAIT
	Synth.beep(660, 0.1); Synth.beep(880, 0.16, "square", 0.05, 0.0, 0.1)
	floater(o.x, o.y, "해킹 %d/3" % o.hackN, Color("#62d0f0"), 16)
	if o.hackN == 2:
		## 사이렌: 8초 동안 오르내리는 경보음 + 단말기 위 붉은 경광등 + 화면 가장자리 붉은 맥동.
		## 대규모 증원을 바로 부르지는 않는다. 대신 정찰대가 더 자주, 더 많이 온다
		banner("침입 감지! 경보 발령. 정찰대가 계속 몰려온다")
		sirenT = 8.0
		siren_next = 0.0
		siren_at = Vector2(o.x, o.y)
		flash = 0.12
		_scout_squad(o, 5 + int(lv() * 3))
		o.scoutT = lerpf(5.5, 3.5, lv())
		## 경보가 울렸으니 증원 요청 대기도 풀린다: 정찰대가 발견하면 곧바로 무전을 칠 수 있다
		rcd = 0.0
	else:
		## 첫 부호: 이상 신호를 확인하러 화면 밖에서 정찰대가 출발한다 (아직 교전 상태는 아니다)
		banner("해킹 1/3. 정찰대가 확인하러 온다. %d초 뒤 다음 부호" % int(HACK_WAIT))
		_scout_squad(o, 4 + int(lv() * 3))
		o.scoutT = lerpf(9.0, 6.0, lv())
		Synth.beep(300, 0.25, "sawtooth", 0.04, 120)


## 정찰대: 화면 밖 한 방향에서 나타나 수색 상태로 단말기 쪽에 온다. 플레이어를 보면 평소처럼 교전·증원 요청으로 이어진다
func _scout_squad(o: Dictionary, n: int) -> void:
	var sa = randf() * TAU
	for i in n:
		if en.size() >= 300:
			break
		var ty = "rf" if i == 0 else "sh" if i == n - 1 and stage >= 4 else "ru"
		var e = spawn(ty, null, null, sa)
		if e == null:
			continue
		e.st = "sus"
		e.home = "post"
		e.aw = 0.45
		e.lookT = 0.0
		e.inv = Vector2(o.x + (randf() - 0.5) * 70, o.y + (randf() - 0.5) * 70)
		e.px = o.x + cos(sa + i) * 60
		e.py = o.y + sin(sa + i) * 60
		e.face = atan2(o.y - e.y, o.x - e.x)
		e.bf = e.face


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
		if ev.physical_keycode == KEY_R and ev.pressed:
			reload_now()
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
			## 진화 알림 시간 (게임은 멈추지 않는다)
			evoT -= raw
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
	var mv = Vector2.ZERO if (ext.state == "leave" or (aim != null and aim_touch != -1 and joy.id == -1)) else move_vec()
	var sp: float = 128.0 * p.m.spd
	if p.dropT > 0:
		## 강하 중: 천천히 흘러가며 착지점만 고른다. 닿는 순간 흙먼지
		sp *= 0.45
		p.dropT -= dt
		if p.dropT <= 0:
			puff(p.x, p.y, Color("#b9ab8c"), 14, 110.0)
			shake = maxf(shake, 3.0)
			Synth.noise(0.16, 0.07, 500)
			Synth.beep(90, 0.14, "sine", 0.07, -40)
	elif p.dropT > -1.0:
		p.dropT -= dt
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
	## 거치 기관총 곁에 서면 올라탄 것으로 본다
	var was_mount = p.mount
	p.mount = null
	for tu in turrets:
		if tu.k == "hmg" and d2(tu, p) < 30 and p.dropT <= 0:
			p.mount = tu
	var mounted: bool = p.mount != null
	if mounted and was_mount == null:
		floater(p.x, p.y, "기관총 탑승", Color("#f2c21b"), 14)
		Synth.beep(520, 0.08, "square", 0.04)
	var w: Dictionary = HMG if mounted else p.w
	var ox: float = p.mount.x if mounted else p.x
	var oy: float = p.mount.y if mounted else p.y
	var ev: Dictionary = p.evo
	if p.reload > 0 and not mounted:
		p.reload -= dt
		if p.reload <= 0:
			p.ammo = mag_size()
	else:
		p.fireT -= dt
		var tg = null
		tg = nearest(p.x, p.y, w.range, true, true, dbg_trace, true)
		p.aim = atan2(tg.y - p.y, tg.x - p.x) if tg != null else turn_to(p.aim, p.face, dt * 14)
		if tg != null and p.dropT <= 0:
			if p.fireT <= 0:
				p.fireT = 1.0 / (w.rate * p.m.rate * (1.5 if p.boostT > 0 else 1.0) * (1.9 if ev.has("lmg") else 1.3 if ev.has("ar") else 1.0))
				var n: int = w.pellets + p.m.multi + (4 if ev.has("sg") else 0)
				var sprd: float = 0.08 if ev.has("lmg") else w.spread
				var ex = {}
				var evw: bool = ev.has(w.id)
				var xp_pierce = 0
				if ev.has("ar"): ex = {rico = 4}
				elif ev.has("sg"):
					ex = {fire = true}
					xp_pierce = 2
				elif ev.has("rail"): ex = {boom = true}
				elif ev.has("lmg"):
					## 미니건: 다섯 발마다 작렬탄
					xp_pierce = 1
					p.shots = p.get("shots", 0) + 1
					if p.shots % 5 == 0:
						ex = {boom_s = true}
				if evw:
					ex.evo = true
				var edmg: float = w.dmg * p.m.dmg * (1.35 if evw else 1.0)
				## 탄은 총구 끝에서 나간다 (소총: 앞 20·오른쪽 2.6 / 거치 기관총: 앞 26, 높이 1 m)
				var mz: Vector2 = muzzle(ox, oy, p.aim, 26.0 if mounted else 20.0, 0.0 if mounted else 2.6)
				if mounted:
					ex.h = 1.02
				for i in n:
					var a: float = p.aim + ((randf() - 0.5) * sprd if w.pellets > 1 else (i - (n - 1) / 2.0) * 0.11 + (randf() - 0.5) * sprd)
					shoot(mz.x, mz.y, a, w, edmg, 99 if ev.has("rail") else w.pierce + p.m.pierce + xp_pierce, ex)
				p.muz = 0.05
				if mounted:
					p.mount.aim = p.aim
					shake = maxf(shake, 1.8)
				if evw:
					## 진화 무기: 반동 흔들림, 총구 섬광 입자, 묵직한 저음
					var wc = wcol()
					shake = maxf(shake, 7.0 if w.id == "rail" else 5.0 if w.id == "sg" else 2.2)
					var mx = mz.x
					var my = mz.y
					for j in (6 if w.id == "rail" or w.id == "sg" else 2):
						if pt.size() < 400:
							var sa = p.aim + (randf() - 0.5) * 0.9
							var ss = 120.0 + randf() * 160
							pt.append({x = mx, y = my, vx = cos(sa) * ss, vy = sin(sa) * ss, t = 0.0, d = 0.18, c = wc, r = 2.5, g = 0.0, h = LIFT, glow = true})
					if w.id == "rail":
						beams.append({x0 = mx, y0 = my, x1 = p.x + cos(p.aim) * w.range, y1 = p.y + sin(p.aim) * w.range, t = 0.0, d = 0.35, w = 0.9, c = wc})
					if t - last_shot > 0.07:
						Synth.beep(110 if w.id != "rail" else 80, 0.12, "sawtooth", 0.05, -50)
				if not ev.has("lmg") and not mounted:
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
				var s = (0.0 if e.T.has("boss") else 40.0 if e.T.has("armor") else 170.0) * dt
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
		if o.type == "boss":
			o.x = o.e.x
			o.y = o.e.y
			if o.e.hp <= 0:
				complete_obj(o)
			continue
		if o.type == "term" and o.hackN >= 1:
			## 해킹이 끝날 때까지 정찰대가 주기적으로 계속 온다 (2단계 뒤에는 더 자주)
			o.scoutT -= dt
			if o.scoutT <= 0:
				o.scoutT = lerpf(5.5, 3.5, lv()) if o.hackN >= 2 else lerpf(9.0, 6.0, lv())
				_scout_squad(o, (4 if o.hackN >= 2 else 3) + int(lv() * 2))
		if o.type == "term" and o.hackT > 0:
			o.hackT -= dt
			if o.hackT <= 0:
				o.code = term_code()
				floater(o.x, o.y, "다음 부호 수신", Color("#f2c21b"), 15)
				Synth.beep(1200, 0.07, "square", 0.04); Synth.beep(1200, 0.07, "square", 0.04, 0.0, 0.12)
		if o.type == "cap":
			if d < o.r and o.hacked:
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
			if o.type == "fac" and d < 900:
				## 굴뚝 연기
				o.spT -= dt
				if o.spT <= 0 and pt.size() < 380:
					o.spT = 0.22
					for cx in [-36.0, -20.0]:
						pt.append({x = o.x + cx, y = o.y - 22, vx = 6.0 + randf() * 6, vy = -4.0, t = 0.0, d = 2.4, c = Color("#3a3836"), r = 5.0, g = 5.0, h = 5.6, rise = 1.4})
			if o.hp <= 0:
				complete_obj(o)
				hs = 0.1
				explode(o.x, o.y, 100, 300, {noFF = true, fixed = true})
		if not o.known and d < 420:
			o.known = true
			banner({aa = "방공포", nest = "적 부대", jam = "미니맵 교란기", fac = "군수공장"}.get(o.type, "목표") + " 발견")
	## 탈출
	if ext.state == "wait":
		ext.t -= dt
		if ext.t <= 0:
			ext.state = "land"
			ext.ship = 0.0
			ext.clearT = 0.0
			ext.landed = false
			banner("헬기 도착. 착륙 지점을 정리한다")
			heli_node = AC.heli()
			dyn.add_child(heli_node)
			Synth.beep(90, 1.6, "sawtooth", 0.05, 20)
	elif ext.state == "land":
		## 착륙장 근처에 적이 있으면 문짝 미니건 사수가 쓸어 준다. 비면 내려앉는다
		var near_e = null
		var near_d = 270.0
		var lz_busy = false
		for e in en:
			if e.hp <= 0:
				continue
			var ed = d2(e, ext)
			if ed < near_d:
				near_d = ed
				near_e = e
			if ed < 170:
				lz_busy = true
		if near_e != null:
			ext.gunT -= dt
			if ext.gunT <= 0:
				ext.gunT = 0.05
				var ga = atan2(near_e.y - ext.y, near_e.x - ext.x)
				beams.append({x0 = ext.x + cos(ga) * 14, y0 = ext.y + sin(ga) * 14, x1 = near_e.x + (randf() - 0.5) * 10, y1 = near_e.y + (randf() - 0.5) * 10, t = 0.0, d = 0.07, w = 0.22, c = Color("#ffd27a")})
				hit_enemy(near_e, 55.0, true)
				near_e.vx += cos(ga) * 40
				near_e.vy += sin(ga) * 40
				if pt.size() < 390:
					pt.append({x = near_e.x, y = near_e.y, vx = (randf() - 0.5) * 80, vy = (randf() - 0.5) * 80, t = 0.0, d = 0.25, c = Color("#c8b89a"), r = 2.0, g = 3.0, h = 0.3})
				if t - last_shot > 0.06:
					last_shot = t
					Synth.noise(0.05, 0.07, 1900)
					Synth.beep(150, 0.05, "sawtooth", 0.03, -40)
		## 0.7까지는 접근·제자리 비행, 착륙장이 0.6초 비어 있으면 마저 내려온다
		ext.clearT = 0.0 if lz_busy else ext.clearT + dt
		var goal = 1.0 if ext.clearT > 0.6 or ext.landed else 0.7
		ext.ship = move_toward(ext.ship, goal, dt / 2.6)
		if ext.ship >= 1 and not ext.landed:
			ext.landed = true
			banner("착륙 완료. 탑승하라")
			Synth.beep(660, 0.1); Synth.beep(880, 0.2, "square", 0.05, 0.0, 0.1)
		if ext.landed and d2(ext, p) < ext.r * 0.7:
			## 탑승: 플레이어는 사라지고 헬기가 급히 떠오른다
			ext.state = "leave"
			ext.out = 0.0
			p.inv = 99.0
			p.reload = 99.0
			aim = null
			banner("탑승 완료. 이탈한다")
			Synth.beep(110, 1.8, "sawtooth", 0.06, 160)
			Synth.noise(1.8, 0.16, 500)
	elif ext.state == "leave":
		ext.out += dt / 2.0
		if ext.out >= 1.0:
			end_game(true)
	## 스폰: 평소에는 맵에 배치된 적만 있다. 탈출 대기 중에만 계속 몰려온다
	if ext.state == "wait":
		spawnT -= dt
		if spawnT <= 0:
			spawnT = 1.0
			var n = minf(9.0, 2.4 + t / 90.0) * reinf_mul
			var ni = int(n) + (1 if randf() < fmod(n, 1.0) else 0)
			for i in ni:
				if en.size() >= 300:
					break
				var r = randf()
				spawn(heavy() if r < 0.04 else "dr" if r < 0.14 else "rf" if r < 0.36 else "sh" if r < 0.5 else "ru")
	rcd -= dt
	if rcall != null and (rcall.hp <= 0 or rcall.st != "call"):
		rcall = null
	## 연출
	for f in fx:
		f.t += dt
	fx = fx.filter(func(f): return f.t < f.d)
	for i in range(jets.size() - 1, -1, -1):
		var j: Dictionary = jets[i]
		if j.has("evade"):
			## 방공망 회피: 급선회하며 플레어를 뿌린다
			j.evade -= dt
			if j.evade <= 0 and j.evade > -1.0:
				var wv: float = 2.5 * j.dir * dt
				var nvx: float = j.vx * cos(wv) - j.vy * sin(wv)
				j.vy = j.vx * sin(wv) + j.vy * cos(wv)
				j.vx = nvx
				j.ang += wv
				j.roll = lerpf(j.get("roll", 0.0), j.dir * 1.25, minf(1.0, dt * 8))
				if pt.size() < 390:
					pt.append({x = j.x, y = j.y, vx = -j.vx * 0.15 + (randf() - 0.5) * 120, vy = -j.vy * 0.15 + (randf() - 0.5) * 120, t = 0.0, d = 1.0, c = Color("#fff0b0"), r = 3.2, g = 0.0, h = j.alt, rise = -2.5, glow = true})
			elif j.evade <= -1.0:
				j.roll = lerpf(j.get("roll", 0.0), 0.0, minf(1.0, dt * 4))
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
	_update_gs(dt)
	_update_squad(dt)
	_update_avs(dt)
	if sirenT > 0:
		sirenT -= dt
		siren_next -= dt
		if siren_next <= 0:
			## 한 번 울림 = 0.55초 올라갔다 0.55초 내려오는 톱니파
			siren_next = 1.1
			Synth.beep(520, 0.55, "sawtooth", 0.05, 430)
			Synth.beep(950, 0.55, "sawtooth", 0.05, -430, 0.55)
	## 전투 음악: 탈출·보스전은 절정, 증원 요청 중이거나 증원이 온 직후는 긴장
	musicT = maxf(0.0, musicT - dt)
	var mlv = 0
	if ext.state == "wait" or ext.state == "land" or ext.state == "leave" or (boss != null and boss.awake and boss.hp > 0):
		mlv = 2
	elif rcall != null or musicT > 0:
		mlv = 1
	Synth.music(0 if over else mlv)
	empT = maxf(0.0, empT - dt)
	satT = maxf(0.0, satT - dt)
	if snipe != null:
		## 저격 지원: 1.1초마다 위협이 가장 큰 적 하나 (증원 요청 중 > 소총병 > 방패병 > 돌격병, 장갑 차량은 큰 피해만)
		snipe.t -= dt
		snipe.ft -= dt
		if snipe.ft <= 0:
			var best = null
			var bs = -1.0
			for e in en:
				if e.hp <= 0 or d2(e, p) > 560:
					continue
				var sc: float = (100.0 if e.st == "call" else 0.0) + (40.0 if e.st == "alert" else 0.0) + {rf = 30.0, sh = 20.0, ru = 10.0, dr = 15.0}.get(e.type, 5.0) - d2(e, p) * 0.01
				if sc > bs:
					bs = sc
					best = e
			if best != null:
				snipe.ft = 1.1
				var sx: float = best.x + cos(snipe.a) * 900
				var sy: float = best.y + sin(snipe.a) * 900
				beams.append({x0 = sx, y0 = sy, x1 = best.x, y1 = best.y, t = 0.0, d = 0.22, w = 0.22, c = Color("#fff3c0")})
				hit_enemy(best, 320.0 * p.m.dmg, true)
				best.vx -= cos(snipe.a) * 160
				best.vy -= sin(snipe.a) * 160
				puff(best.x, best.y, Color("#8a2a20"), 6, 160)
				Synth.noise(0.09, 0.2, 3200)
				Synth.beep(180, 0.25, "sawtooth", 0.03, -100, 0.12)
			else:
				snipe.ft = 0.25
		if snipe.t <= 0:
			snipe = null
	for i in range(sams.size() - 1, -1, -1):
		var sm: Dictionary = sams[i]
		sm.t += dt
		var sk: float = clampf(sm.t / sm.d, 0.0, 1.0)
		if pt.size() < 390:
			pt.append({x = lerpf(sm.x0, sm.x1, sk), y = lerpf(sm.y0, sm.y1, sk), vx = 0.0, vy = 0.0, t = 0.0, d = 0.8, c = Color("#e0e2e6"), r = 2.5, g = 5.0, h = lerpf(1.5, sm.alt, pow(sk, 0.7))})
		if sm.t >= sm.d:
			## 공중 폭발 + 떨어지는 파편
			sams.remove_at(i)
			sm.node.queue_free()
			fx.append({x = sm.x1, y = sm.y1, r = 46.0, t = 0.0, d = 0.4, h = sm.alt})
			for q in 12:
				if pt.size() < 390:
					var da = randf() * TAU
					var ds = 60.0 + randf() * 140
					pt.append({x = sm.x1, y = sm.y1, vx = cos(da) * ds, vy = sin(da) * ds, t = 0.0, d = 0.9 + randf() * 0.5, c = Color("#ffb060") if q % 2 == 0 else Color("#4a4640"), r = 2.5, g = 0.0 if q % 2 == 0 else 4.0, h = sm.alt, rise = -5.0, glow = q % 2 == 0})
			flash = maxf(flash, 0.08)
			shake = minf(12.0, shake + 4.0)
			Synth.noise(0.4, 0.2, 500)
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


## 적 곡사 포탄·미사일: 빛나는 탄체가 연기 꼬리를 끌며 포물선으로 날아온다 (피해는 탄착 예고 쪽에서 준다)
func _shell_lob(x0: float, y0: float, x1: float, y1: float, d: float, hgt: float, missile: bool) -> void:
	var n = Node3D.new()
	if missile:
		MK.inst(n, MK.cached("e_missile", func():
			var k = MK.new()
			k.cyl(0.1, 0.1, 1.2, Vector3.ZERO, "#d8dce0", "x", 8)
			k.lathe([Vector2(0.1, 0.0), Vector2(0.0, 0.35)], Vector3(0.6, 0, 0), "#a8322a", Vector3(0, 0, -PI / 2), 8)
			for a in 4:
				k.box(Vector3(0.28, 0.26, 0.02), Vector3(-0.45, 0, 0), "#8d959c", Vector3(a * PI / 2 + PI / 4, 0, 0))
			return k.commit()))
		ML.no_shadow(ML.sph(n, 0.16, "#ffb046", Vector3(-0.8, 0, 0), Vector3(2.4, 1, 1), ML.add_mat("#ffb046", 0.95), 8))
	else:
		MK.inst(n, MK.cached("e_shell", func():
			var k = MK.new()
			k.cyl(0.13, 0.13, 0.5, Vector3.ZERO, "#3a3d36", "x", 8)
			k.lathe([Vector2(0.13, 0.0), Vector2(0.07, 0.2), Vector2(0.0, 0.34)], Vector3(0.25, 0, 0), "#2a2c27", Vector3(0, 0, -PI / 2), 8)
			return k.commit()))
		ML.no_shadow(ML.sph(n, 0.26, "#ff8a2a", Vector3.ZERO, Vector3(1.6, 1, 1), ML.add_mat("#ff8a2a", 0.55), 8))
	dyn.add_child(n)
	lobs.append({x0 = x0, y0 = y0, x1 = x1, y1 = y1, t = 0.0, d = d, fn = func(): pass, node = n, hgt = hgt, trail = true, c = Color("#d8dce0") if missile else Color("#6a665e")})


func _lob(x0: float, y0: float, x1: float, y1: float, d: float, fn: Callable) -> void:
	var n = Node3D.new()
	ML.sph(n, 0.12, "#3f4636", Vector3.ZERO, Vector3.ONE, null, 6)
	dyn.add_child(n)
	lobs.append({x0 = x0, y0 = y0, x1 = x1, y1 = y1, t = 0.0, d = d, fn = fn, node = n})


## ---------- 보스 행동 ----------
## 공통: 한 번 깨어나면(가까이 가거나, 맞거나, 전장이 시끄러워지면) 끝까지 싸운다. 엄폐물은 밟아 부순다
func _boss_ai(e: Dictionary, dt: float) -> void:
	var dx: float = p.x - e.x
	var dy: float = p.y - e.y
	var d = maxf(1.0, sqrt(dx * dx + dy * dy))
	var hpk: float = e.hp / e.maxhp
	if not e.awake:
		if d < 480 or e.hp < e.maxhp or heat > 0 or (alertN > 0 and d < 900):
			e.awake = true
			e.st = "alert"
			banner("%s 가동!" % e.T.n)
			Synth.beep(70, 1.2, "sawtooth", 0.07, 40)
			Synth.noise(0.8, 0.2, 300)
			shake = maxf(shake, 8.0)
		return
	var a: float = atan2(dy, dx)
	e.face = a
	e.sv = 1.0 if los(e.x, e.y, p.x, p.y) else 0.0
	## 이동 (열차포는 제자리)
	var want: float = 240.0 if e.type == "b1" else 330.0
	if e.T.spd > 0 and e.aimT <= 0:
		e.ha = turn_to(e.get("ha", a), a, dt * 0.8)
		if d > want:
			e.x += cos(a) * e.T.spd * dt
			e.y += sin(a) * e.T.spd * dt
			e.crushT -= dt
			if e.crushT <= 0:
				e.crushT = 0.35
				blast_props(e.x + cos(a) * e.r * 0.6, e.y + sin(a) * e.r * 0.6, e.r * 0.7, 9999.0)
	## 플레이어가 몸 안으로 들어오지 못하게 밀어낸다
	if d < e.r + p.r:
		p.x = e.x + dx / d * (e.r + p.r)
		p.y = e.y + dy / d * (e.r + p.r)
	## 부포: 기관포 3점사 (살아 있는 포탑 수만큼 번갈아)
	var subs: int = 2
	if e.type == "b1":
		subs = 2 if hpk > 0.66 else 1 if hpk > 0.33 else 0
	if e.burst > 0:
		e.bt -= dt
		if e.bt <= 0:
			e.bt = 0.1
			e.burst -= 1
			e.side = -e.side
			var la: float = a + (randf() - 0.5) * 0.09
			var sm: Vector2 = muzzle(e.x, e.y, la, e.r * 0.9, e.side * e.r * 0.45)
			eb.append({x = sm.x, y = sm.y, vx = cos(la) * 360, vy = sin(la) * 360, life = 1.5, dmg = 7.0, ac = true})
			fx.append({x = sm.x, y = sm.y, r = 12.0, t = 0.0, d = 0.1, h = 1.6})
			if d < 700:
				Synth.noise(0.07, 0.12, 1300)
	elif subs > 0:
		e.shoot -= dt
		if e.shoot <= 0 and d < 450 and e.sv > 0:
			e.shoot = (1.5 if hpk > 0.5 else 1.05) * (1.0 if subs == 2 else 1.6)
			e.burst = 3 * subs
			e.bt = 0.0
	## 주포
	if e.type == "b2":
		## 열차포: 맵 어디든 초대형 포탄. 3.2초 전에 큰 탄착 예고
		e.msT -= dt
		if e.msT <= 0:
			e.msT = 9.0 if hpk > 0.5 else 6.5
			e.rec = 1.0
			e.aimA = a
			var tx: float = p.x + p.fx * 46 + (randf() - 0.5) * 40
			var ty: float = p.y + p.fy * 46 + (randf() - 0.5) * 40
			tele.append({x = tx, y = ty, r = 120.0, t = 3.2, max = 3.2, d = e.T.dmg})
			_shell_lob(e.x + cos(a) * 110, e.y + sin(a) * 110, tx, ty, 3.2, 34.0, false)
			fx.append({x = e.x + cos(a) * 120, y = e.y + sin(a) * 120, r = 60.0, t = 0.0, d = 0.35, h = 5.0})
			fx.append({x = e.x, y = e.y, r = 160.0, t = 0.0, d = 0.7, c = Color("#b8a888")})
			Synth.noise(1.0, 0.3, 160)
			Synth.beep(45, 0.9, "sawtooth", 0.08, -15)
			if d < 900:
				shake = minf(20.0, shake + 12.0)
	else:
		## 전차포 직사 (조준선 → 발사)
		if e.aimT > 0:
			e.aimT -= dt
			if e.aimT > 0.25:
				e.aimA = a
			if e.aimT <= 0:
				_tank_fire(e)
		else:
			e.atk -= dt
			if e.atk <= 0 and d < 520 and e.sv > 0:
				e.atk = 4.2 if hpk > 0.5 else 3.0
				e.aimT = 0.8
				e.aimA = a
	if e.type == "b3":
		## 요새: 미사일 연사 + 체력 구간 이벤트
		e.msT -= dt
		if e.msT <= 0 and d < 950:
			e.msT = 7.0 if hpk > 0.4 else 4.8
			var ex0: float = e.x
			var ey0: float = e.y
			for i in (4 if hpk > 0.4 else 6):
				var tx2: float = p.x + p.fx * 36 * i + (randf() - 0.5) * 110
				var ty2: float = p.y + p.fy * 36 * i + (randf() - 0.5) * 110
				later(i * 0.25, func():
					tele.append({x = tx2, y = ty2, r = 54.0, t = 2.0, max = 2.0, d = 20.0})
					_shell_lob(ex0 - 60, ey0, tx2, ty2, 2.0, 12.0, true)
					Synth.noise(0.4, 0.1, 1500))
		if e.bph == 0 and hpk <= 0.75:
			e.bph = 1
			e.aa = false
			var an = e.node.get_node_or_null("Hull/AA")
			if an:
				an.visible = false
			explode(e.x - 55, e.y, 50, 0, {noFF = true, fixed = true})
			banner("요새 방공 포탑 파괴! 이제 항공 지원이 요새에 닿는다" if _aa_src() == null else "요새 방공 포탑 파괴. 남은 방공포를 부숴라")
		if e.bph == 1 and hpk <= 0.5:
			e.bph = 2
			banner("요새가 구조 신호를 보냈다. 증원 접근 중")
			reinforce(e)
	if e.type == "b1":
		## 부포탑이 하나씩 떨어져 나간다
		var lost = 2 - subs
		if lost > e.bph:
			e.bph = lost
			var sn = e.node.get_node_or_null("Hull/SubL" if lost == 1 else "Hull/SubR")
			if sn:
				sn.visible = false
			explode(e.x + cos(a) * 30, e.y + sin(a) * 30, 46, 0, {noFF = true, fixed = true})
			banner("부포탑 파괴! %d개 남았다" % subs if subs > 0 else "부포탑 전부 파괴. 주포만 남았다")


## 전차 주포 발사: 포구 화염·연기·먼지 고리·반동·굉음 + 직사 포탄
func _tank_fire(e: Dictionary) -> void:
	var a: float = e.aimA
	var ca = cos(a)
	var sa = sin(a)
	var lt: bool = e.type == "lt"
	var md: float = {lt = 46.0, b1 = 96.0, b3 = 112.0}.get(e.type, 60.0)
	var mx: float = e.x + ca * md
	var my: float = e.y + sa * md
	eb.append({x = mx, y = my, vx = ca * (500 if lt else 440), vy = sa * (500 if lt else 440), life = 1.6 if e.T.has("boss") else 1.25, dmg = e.T.dmg, shell = true, br = 34.0 if lt else 62.0 if e.T.has("boss") else 46.0})
	e.rec = 1.0
	e.vx -= ca * 60
	e.vy -= sa * 60
	fx.append({x = mx, y = my, r = 34.0, t = 0.0, d = 0.22})
	fx.append({x = e.x, y = e.y, r = 80.0, t = 0.0, d = 0.5, c = Color("#b8a888")})
	for i in 12:
		if pt.size() < 390:
			var sa2 = a + (randf() - 0.5) * 0.7
			var ss = 180.0 + randf() * 260
			pt.append({x = mx, y = my, vx = cos(sa2) * ss, vy = sin(sa2) * ss, t = 0.0, d = 0.25, c = Color("#ffd27a"), r = 2.5, g = 0.0, h = 2.0, glow = true})
	for i in 7:
		if pt.size() < 390:
			var sa3 = a + (randf() - 0.5) * 1.4
			pt.append({x = mx, y = my, vx = cos(sa3) * (30 + randf() * 50), vy = sin(sa3) * (30 + randf() * 50), t = 0.0, d = 1.2 + randf() * 0.5, c = Color("#4a4640"), r = 5.0, g = 7.0, h = 2.0, rise = 1.2})
	if d2(e, p) < 650:
		shake = minf(14.0, shake + 7.0)
		Synth.noise(0.45, 0.26, 320)
		Synth.beep(68, 0.4, "sawtooth", 0.07, -34)
		Synth.beep(1400, 0.05, "square", 0.03, -900)


func _update_enemies(dt: float) -> void:
	alertN = 0
	susN = 0
	## 플레이어를 실제로 보고 있는 적이 있으면 넓은 범위의 적에게 위치가 퍼진다
	var rush: bool = ext.state == "wait" or ext.state == "land"
	shareT -= dt
	if shareT <= 0:
		shareT = 0.5
		if rush:
			for f in en:
				if f.hp > 0 and f.st != "alert" and f.frz <= 0:
					alert_e(f, true)
		var spot = false
		for e in en:
			if e.hp > 0 and (e.st == "alert" or e.st == "call") and e.sv > 0 and e.frz <= 0:
				spot = true
				break
		if spot:
			for f in en:
				if f.hp <= 0 or f.st == "alert" or f.st == "call" or f.frz > 0:
					continue
				var fd = d2(f, p)
				if fd < SHARE_ALERT:
					alert_e(f, true)
				elif fd < SHARE_SUS:
					f.st = "sus"
					f.inv = Vector2(p.x, p.y)
					f.aw = maxf(f.aw, 0.6)
					f.lookT = 0.0
	for e in en:
		if e.burn > 0:
			e.burn -= dt
			e.hp -= 20 * p.m.dmg * dt
		e.flash -= dt
		e.alT -= dt
		e.rec = maxf(0.0, e.rec - dt * 2.6)
		if e.type == "sn":
			## 길리 저격수: 제자리에서 조준선을 1.5초 겨눈 뒤 빠른 한 발. 쏘고 나면 2.5초 동안 드러난다
			e.vx = 0.0
			e.vy = 0.0
			e.rev = maxf(0.0, e.rev - dt)
			if e.frz > 0:
				e.frz -= dt
				e.aimT = 0.0
				continue
			var sdx: float = p.x - e.x
			var sdy: float = p.y - e.y
			var sd = maxf(1.0, sqrt(sdx * sdx + sdy * sdy))
			e.chk -= dt
			if e.chk <= 0:
				e.chk = 0.15
				var hid = sd > e.T.vis or p.inv > 2 or not los(e.x, e.y, p.x, p.y)
				if not hid:
					for z in zones:
						if z.k == "smoke" and (d2(z, p) < z.r or d2(z, e) < z.r):
							hid = true
				e.sv = 0.0 if hid else 1.0
			if e.aimT > 0:
				e.aimT -= dt
				if e.sv <= 0:
					e.aimT = 0.0
				elif e.aimT > 0.3:
					e.aimA = atan2(sdy, sdx)
					e.face = e.aimA
				if e.aimT <= 0 and e.sv > 0:
					var smz: Vector2 = muzzle(e.x, e.y, e.aimA, 24.0, 0.0)
					eb.append({x = smz.x, y = smz.y, vx = cos(e.aimA) * 950, vy = sin(e.aimA) * 950, life = 0.6, dmg = e.T.dmg})
					beams.append({x0 = smz.x, y0 = smz.y, x1 = e.x + cos(e.aimA) * sd, y1 = e.y + sin(e.aimA) * sd, t = 0.0, d = 0.25, w = 0.16, c = Color("#ffe6c0")})
					e.rev = 2.5
					e.shoot = 3.6
					Synth.noise(0.12, 0.24, 2600)
					Synth.beep(140, 0.3, "sawtooth", 0.04, -70, 0.1)
			else:
				e.shoot -= dt
				if e.shoot <= 0 and e.sv > 0:
					e.aimT = 1.5
					e.aimA = atan2(sdy, sdx)
					Synth.beep(1900, 0.05, "sine", 0.03)
			continue
		if e.T.has("boss"):
			## 보스는 전용 행동 (밀리지 않는다)
			e.vx = 0.0
			e.vy = 0.0
			if e.frz > 0:
				e.frz = minf(e.frz, 3.0) - dt
			else:
				_boss_ai(e, dt)
			continue
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
			if e.sv > 0 or rush:
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
				## 사격 거리에 들면 멈춰 서서 쏜다. 한 번 서면 꽤 멀어지거나 시야를 잃어야 다시 쫓는다.
				## 아주 가까이 붙었을 때만 천천히 물러선다 (예전에는 150 안에서 계속 뒷걸음질해 벽·동료와 부딪혀 떨었다)
				if e.hold:
					if d > 250 or e.seen > 1.2:
						e.hold = false
				elif d < 185 and e.sv > 0:
					e.hold = true
				if e.hold:
					sp = -s * 0.4 if d < 60 else 0.0
				e.shoot -= dt
				if e.shoot <= 0 and d < 260 and e.sv > 0:
					e.shoot = 1.9
					## 더 가까운 부대원이 있으면 열 번에 네 번은 그쪽을 쏜다
					var sa2: float = atan2(dy, dx)
					if randf() < 0.4:
						var sbd: float = d
						for m in squad:
							if m.down <= 0 and d2(m, e) < sbd:
								sbd = d2(m, e)
								sa2 = atan2(m.y - e.y, m.x - e.x)
					var emz: Vector2 = muzzle(e.x, e.y, sa2, 20.0)
					eb.append({x = emz.x, y = emz.y, vx = cos(sa2) * 175, vy = sin(sa2) * 175, life = 2.0, dmg = e.T.dmg})
			if e.type == "lt":
				## 경전차: 포탄이 아니라 기관포 3점사. 조준선 없이 끊어 쏜다
				e.ha = turn_to(e.get("ha", e.face), e.face, dt * 2.2)
				if d < 170:
					sp = 0.0
				if e.burst > 0:
					e.bt -= dt
					if e.bt <= 0:
						e.bt = 0.11
						e.burst -= 1
						var la: float = atan2(dy, dx) + (randf() - 0.5) * 0.07
						var lmz: Vector2 = muzzle(e.x, e.y, la, 46.0, 0.0)
						eb.append({x = lmz.x, y = lmz.y, vx = cos(la) * 360, vy = sin(la) * 360, life = 1.4, dmg = e.T.dmg * 0.55, ac = true})
						e.rec = 0.45
						fx.append({x = lmz.x, y = lmz.y, r = 12.0, t = 0.0, d = 0.1, h = 1.1})
						if d < 650:
							Synth.noise(0.07, 0.13, 1300)
							Synth.beep(170, 0.07, "sawtooth", 0.04, -60)
				else:
					e.shoot -= dt
					if e.shoot <= 0 and d < 400 and e.sv > 0:
						e.shoot = 1.7
						e.burst = 3
						e.bt = 0.0
			elif e.type == "tk":
				var lt: bool = false
				e.ha = turn_to(e.get("ha", e.face), e.face, dt * (2.2 if lt else 1.4))
				## 전차: 붉은 조준선을 0.7초 겨눈 뒤 포탄을 직사한다. 돌진하지 않고 거리를 둔다
				if d < 180:
					sp = 0.0
				if e.aimT > 0:
					e.aimT -= dt
					sp = 0.0
					if e.aimT > 0.22:
						e.aimA = atan2(dy, dx)
					if e.aimT <= 0:
						_tank_fire(e)
				else:
					e.shoot -= dt
					if e.shoot <= 0 and d < 420 and e.sv > 0:
						## 경전차는 덜 아프지만 자주 쏜다
						e.shoot = 2.0 if lt else 3.4
						e.aimT = 0.45 if lt else 0.7
						e.aimA = atan2(dy, dx)
			elif e.type == "ml":
				e.ha = turn_to(e.get("ha", e.face), e.face, dt * 0.9)
				## 미사일 발사대: 아주 멀리서 4발을 연달아 쏜다. 탄착 자리가 2초 전에 표시된다
				sp = s if d > 760 else -s * 0.6 if d < 380 else 0.0
				e.shoot -= dt
				if e.shoot <= 0 and d < 900:
					e.shoot = 7.5
					e.rec = 1.0
					var la: float = atan2(dy, dx)
					for i in 4:
						var tx2: float = p.x + p.fx * 40 * i + (randf() - 0.5) * 90
						var ty2: float = p.y + p.fy * 40 * i + (randf() - 0.5) * 90
						var ex0: float = e.x
						var ey0: float = e.y
						later(i * 0.3, func():
							tele.append({x = tx2, y = ty2, r = 54.0, t = 2.0, max = 2.0, d = 20.0})
							_shell_lob(ex0, ey0, tx2, ty2, 2.0, 11.0, true)
							fx.append({x = ex0 + cos(la) * 20, y = ey0 + sin(la) * 20, r = 20.0, t = 0.0, d = 0.2, h = 2.6})
							for q in 4:
								if pt.size() < 390:
									pt.append({x = ex0, y = ey0, vx = -cos(la) * 60 + (randf() - 0.5) * 50, vy = -sin(la) * 60 + (randf() - 0.5) * 50, t = 0.0, d = 1.3, c = Color("#d8dce0"), r = 5.0, g = 7.0, h = 2.2, rise = 0.8})
							if d2({x = ex0, y = ey0}, p) < 950:
								Synth.noise(0.5, 0.13, 1500)
								Synth.beep(240, 0.5, "sawtooth", 0.035, 500))
			elif e.type == "sp":
				e.ha = turn_to(e.get("ha", e.face), e.face, dt * 1.0)
				## 자주포: 멀리서 곡사. 떨어질 자리를 미리 표시한다 (시야가 없어도 쏜다)
				sp = s if d > 520 else -s * 0.5 if d < 260 else 0.0
				e.shoot -= dt
				if e.shoot <= 0 and d < 640:
					e.shoot = 4.2
					e.rec = 1.0
					var stx: float = p.x + p.fx * 26 + (randf() - 0.5) * 30
					var sty: float = p.y + p.fy * 26 + (randf() - 0.5) * 30
					tele.append({x = stx, y = sty, r = 58.0, t = 1.5, max = 1.5, d = 22.0})
					## 포탄이 높이 솟았다가 표시된 자리로 떨어지는 것이 보인다
					_shell_lob(e.x + cos(atan2(dy, dx)) * 50, e.y + sin(atan2(dy, dx)) * 50, stx, sty, 1.5, 16.0, false)
					var ma: float = atan2(dy, dx)
					fx.append({x = e.x + cos(ma) * 40, y = e.y + sin(ma) * 40, r = 24.0, t = 0.0, d = 0.2})
					for i in 5:
						if pt.size() < 390:
							pt.append({x = e.x + cos(ma) * 44, y = e.y + sin(ma) * 44, vx = cos(ma) * 30 + (randf() - 0.5) * 40, vy = sin(ma) * 30 + (randf() - 0.5) * 40, t = 0.0, d = 1.1, c = Color("#5a5650"), r = 5.0, g = 6.0, h = 3.2, rise = 1.6})
					if d < 700:
						Synth.noise(0.35, 0.16, 260)
						Synth.beep(60, 0.3, "sawtooth", 0.05, -20)
		elif e.st == "call":
			e.face = atan2(dy, dx)
			e.callT -= dt
			if e.callT <= 0:
				e.st = "alert"
				reinforce(e)
		else:
			if e.sv > 0:
				e.aw += dt * (0.65 + e.sv * 2.7) * (1.0 if p.mv else 0.6)
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
			if e.T.has("armor"):
				e.ha = turn_to(e.get("ha", e.face), e.face, dt * 1.2)
			if d < e.r + p.r + 8:
				alert_e(e)
		## 플레이어와 맞닿으면 더 밀고 들어오지 않고 그 자리에서 공격한다 (자폭 드론은 예외)
		var fly: bool = e.T.get("fly", false)
		if not fly and d < e.r + p.r + 2.0:
			sp = minf(sp, 0.0)
		e.x += (tx * sp + e.vx) * dt
		e.y += (ty * sp + e.vy) * dt
		e.vx *= 1 - minf(1, dt * 6)
		e.vy *= 1 - minf(1, dt * 6)
		e.walk += dt * absf(sp) * 0.13
		## 플레이어 몸과 겹치지 않게 적을 밀어낸다 (플레이어는 밀리지 않는다)
		if not fly:
			var ox: float = e.x - p.x
			var oy: float = e.y - p.y
			var od = sqrt(ox * ox + oy * oy)
			var omin: float = e.r + p.r
			if od < omin and od > 0.01:
				e.x = p.x + ox / od * omin
				e.y = p.y + oy / od * omin
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
		var dead: bool = b.life <= 0 or b.x < 0 or b.y < 0 or b.x >= WORLD or b.y >= WORLD
		if not dead:
			for o in map.objs:
				if is_dest(o) and not o.done and Vector2(o.x - b.x, o.y - b.y).length() < o.r:
					o.hp -= b.dmg
					dead = true
					break
		if not dead and blocked(b.x, b.y):
			dead = true
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
							var kd = 5.0 if e.T.has("armor") else 1.0
							e.vx += b.vx / q * b.kb / kd
							e.vy += b.vy / q * b.kb / kd
							if b.get("fire", false):
								e.burn = 3.0
							if b.get("boom", false):
								explode(e.x, e.y, 60, b.dmg * 0.9, {noFF = true, small = true})
							if b.get("boom_s", false):
								explode(e.x, e.y, 34, b.dmg * 1.6, {noFF = true, small = true})
							if pt.size() < 400:
								pt.append({x = b.x, y = b.y, vx = -b.vx * 0.1 + (randf() - 0.5) * 60, vy = -b.vy * 0.1 + (randf() - 0.5) * 60, t = 0.0, d = 0.15, c = Color("#fff3a0"), r = 1.5, g = 0.0, h = LIFT})
							if b.get("evo", false):
								_evo_hit(b, e)
							b.hit.append(e.uid)
							if b.pierce > 0:
								b.pierce -= 1
							elif b.get("rico", 0) > 0:
								var nb = null
								var nd = 200.0
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
		var shell: bool = b.get("shell", false)
		## 빠른 탄이 한 프레임에 플레이어를 건너뛰지 않게, 이번 프레임에 지나온 선분과의 거리로 판정한다
		var pp = Vector2(p.x, p.y)
		var hit_d = Geometry2D.get_closest_point_to_segment(pp, Vector2(b.x - b.vx * dt, b.y - b.vy * dt), Vector2(b.x, b.y)).distance_to(pp)
		if hit_d < p.r + (9 if shell else 4):
			if shell:
				enemy_blast(b.x, b.y, b.get("br", 46.0), b.dmg)
				b.shell = false
			else:
				hurt(b.dmg)
			b.life = 0.0
		## 부대원·드론도 맞는다
		if b.life > 0 and (squad.size() > 0 or drones.size() > 0):
			for a in squad + drones:
				if a.down <= 0 and Vector2(a.x - b.x, a.y - b.y).length() < (13 if shell else 9):
					if shell:
						enemy_blast(b.x, b.y, b.get("br", 46.0), b.dmg)
						b.shell = false
					else:
						ally_hurt(a, b.dmg)
					b.life = 0.0
					break
		if b.life <= 0 or blocked(b.x, b.y):
			if b.get("shell", false):
				enemy_blast(b.x, b.y, b.get("br", 46.0), b.dmg)
			eb.remove_at(i)
		elif shell and pt.size() < 390:
			## 포탄 꼬리 연기
			pt.append({x = b.x, y = b.y, vx = 0.0, vy = 0.0, t = 0.0, d = 0.35, c = Color("#8a857c"), r = 2.0, g = 5.0, h = LIFT})


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
		elif z.k == "smoke":
			## 연막: 굵은 연기를 계속 피운다
			if randf() < dt * 9 and pt.size() < 380:
				var a = randf() * TAU
				var rr = sqrt(randf()) * z.r * 0.9
				pt.append({x = z.x + cos(a) * rr, y = z.y + sin(a) * rr, vx = (randf() - 0.5) * 10, vy = (randf() - 0.5) * 10, t = 0.0, d = 2.6, c = Color("#c4c8cc"), r = 9.0, g = 9.0, h = 0.6, rise = 0.9})
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
		if tu.k == "hmg":
			pass
		elif tu.k == "gun":
			var tg = nearest(tu.x, tu.y, 260, true, true)
			if tg != null:
				tu.aim = atan2(tg.y - tu.y, tg.x - tu.x)
				if tu.fireT <= 0:
					tu.fireT = 0.12
					make_noise(tu.x, tu.y, 260, tu)
					var tmz: Vector2 = muzzle(tu.x, tu.y, tu.aim, 25.0, 0.0)
					shoot(tmz.x, tmz.y, tu.aim + (randf() - 0.5) * 0.08, {speed = 560.0, range = 270.0, kb = 15.0}, 13 * p.m.dmg, 0, {h = 0.8})
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
	_update_drones(dt)
	for i in range(mis.size() - 1, -1, -1):
		var s: Dictionary = mis[i]
		if s.d > 0:
			s.d -= dt
			continue
		s.life -= dt
		## 표적이 살아 있으면 계속 쫓고, 죽으면 근처의 다른 적으로 바꾼다
		if s.tg != null and s.tg.hp <= 0:
			s.tg = nearest(s.tx, s.ty, 220, false)
		if s.tg != null:
			s.tx = s.tg.x
			s.ty = s.tg.y
		var mdx: float = s.tx - s.x
		var mdy: float = s.ty - s.y
		var md = sqrt(mdx * mdx + mdy * mdy)
		s.a += clampf(ang_d(atan2(mdy, mdx), s.a), -3.5 * dt, 3.5 * dt)
		s.x += cos(s.a) * 640 * dt
		s.y += sin(s.a) * 640 * dt
		## 마지막 구간에서 내리꽂힌다
		s.alt = clampf(md / 640.0 * 11.0, 0.8, 15.0)
		if pt.size() < 390:
			pt.append({x = s.x - cos(s.a) * 20, y = s.y - sin(s.a) * 20, vx = 0.0, vy = 0.0, t = 0.0, d = 0.6, c = Color("#d8dce2"), r = 2.5, g = 4.0, h = s.alt})
		if s.life <= 0 or md < 26:
			mis.remove_at(i)
			s.node.queue_free()
			explode(s.tx if md < 26 else s.x, s.ty if md < 26 else s.y, 70, 420, {noFF = true})
			shake = minf(18.0, shake + 6.0)
	for i in range(lobs.size() - 1, -1, -1):
		var l: Dictionary = lobs[i]
		l.t += dt
		if l.get("trail", false) and pt.size() < 390:
			var lk: float = clampf(l.t / l.d, 0.0, 1.0)
			pt.append({x = lerpf(l.x0, l.x1, lk), y = lerpf(l.y0, l.y1, lk), vx = 0.0, vy = 0.0, t = 0.0, d = 0.5, c = l.c, r = 2.0, g = 4.0, h = 0.6 + sin(lk * PI) * l.hgt})
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
	var zk = 0.0
	_cam_place(tp + sh + Vector3(0, 0, 1.6), 25.0 - 11.0 * zk - dbg_zoom, 56.0 - 10.0 * zk - dbg_zoom * 0.9)
	sun.directional_shadow_max_distance = 70.0
	## 플레이어
	if player_node:
		## 낙하산 강하: 위에서 흔들리며 내려오고, 닿으면 캐노피가 옆으로 꺼진다
		var dk: float = clampf(p.dropT / DROP, 0.0, 1.0)
		var fold: float = clampf(-p.dropT / 0.5, 0.0, 1.0)
		player_node.position = tp + Vector3(0, DROP_H * (0.65 * dk + 0.35 * dk * dk), 0)
		player_node.rotation = Vector3(0, -p.aim, sin(t * 3.2) * 0.13 * dk)
		player_node.visible = ext.state != "leave" and not (p.inv > 0 and p.dropT <= 0 and int(t * 12) % 2 == 1)
		AC.walk(player_node, t * 11.0, 1.0 if p.mv and p.dropT <= 0 else 0.0)
		AC.set_flash(player_node, p.hurtT > 0)
		shield_node.visible = p.shieldT > 0
		chute_node.visible = p.dropT > -0.5
		if chute_node.visible:
			chute_node.rotation = Vector3(0, p.aim, fold * 1.25)
			chute_node.scale = Vector3(1.0 + 0.2 * fold, 1.0 - 0.8 * fold, 1.0 + 0.2 * fold)
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
	if gs != null:
		var gn: Node3D = gs.node
		gn.position = p3(gs.x, gs.y, 7.5 + sin(t * 1.7) * 0.25)
		gn.rotation = Vector3(0.07 * sin(t * 1.1), -gs.face, -0.13)
		gn.get_node("Rotor").rotation.y += raw * 30.0
		gn.get_node("TailRotor").rotation.z += raw * 40.0
	for j in jets:
		j.node.position = p3(j.x, j.y, j.alt)
		j.node.rotation = Vector3(0.25 * sin(t * 3 + j.x * 0.01) + j.get("roll", 0.0), -j.ang, 0)
	for sm in sams:
		var sk2: float = clampf(sm.t / sm.d, 0.0, 1.0)
		sm.node.position = p3(lerpf(sm.x0, sm.x1, sk2), lerpf(sm.y0, sm.y1, sk2), lerpf(1.5, sm.alt, pow(sk2, 0.7)))
		sm.node.rotation = Vector3(0, -atan2(sm.y1 - sm.y0, sm.x1 - sm.x0), 0.5 * (1.0 - sk2))
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
		if e.T.has("armor"):
			n.position = p3(e.x, e.y)
			n.get_node("Hull").rotation.y = -e.get("ha", a)
			## 포탑은 조준 중이면 조준선 방향. 발사 반동으로 뒤로 밀렸다 돌아온다
			var ta: float = e.aimA if e.aimT > 0 or e.rec > 0.3 else a
			var tur: Node3D = n.get_node("Turret")
			tur.rotation.y = -ta
			tur.position = Vector3(0, e.T.get("th", 1.1), 0) - Vector3(cos(ta), 0, sin(ta)) * 0.32 * e.rec
		elif e.type == "dr":
			n.position = p3(e.x, e.y, 1.3 + sin(t * 6 + e.ph) * 0.12)
			n.rotation.y = -a
		elif e.type == "sn":
			n.position = p3(e.x, e.y)
			n.rotation.y = -e.face
		else:
			n.position = p3(e.x, e.y)
			n.rotation.y = -a
			AC.walk(n, e.walk, 0.0 if e.frz > 0 else 1.0 if e.walk != e.get("lw", -1.0) else 0.0)
			e.lw = e.walk
		AC.set_flash(n, e.flash > 0)
		var lb: Label3D = e.lb
		if e.type == "sn":
			n.get_node("Body/Glint").visible = e.rev > 0 or (e.aimT > 0 and int(t * 10) % 2 == 0)
			lb.visible = e.rev > 0
			lb.text = "!"
			lb.modulate = Color("#ff3a2a")
			continue
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
			if o.type == "jam":
				n.get_node("Live/Spin").rotation.y = t * 1.6
		var lb: Label3D = o.label
		lb.visible = not o.done and o.known
		match o.type:
			"cap": lb.text = ("통신탑 점령 %d%%" % roundi(o.prog * 100)) if o.hacked else "통신탑: 부호 입력"
			"nest": lb.text = "적 부대 파괴"
			"aa": lb.text = "방공포 파괴"
			"boss":
				lb.text = "★ " + o.e.T.n
				lb.position = p3(o.x, o.y, 9.0)
			"jam": lb.text = "교란기 파괴"
			"fac": lb.text = "군수공장 파괴"
			_:
				if o.hackT > 0:
					lb.text = "★ 단말기 %d/3 · 다음 부호 %d초" % [o.hackN, ceili(o.hackT)]
				else:
					lb.text = "★ 단말기 %d/3: 부호 입력" % (o.hackN + 1)
					for m in squad:
						if m.role == "eng" and m.hackT > 0:
							lb.text = "★ 단말기 %d/3: 공병 송신 중 %d%%" % [o.hackN + 1, int(m.hackT / sq_hack_need() * 100)]
		lb.modulate = Color("#f2f0e8")
	## 포탑·드론·지뢰·미사일·투척물
	for tu in turrets:
		var g: Node3D = tu.node.get_node("Gun")
		g.rotation.y = -tu.aim
	for d in drones:
		d.node.visible = d.down <= 0
		d.node.position = p3(d.x, d.y, 1.6 + sin(t * 7 + d.a) * 0.1)
		d.node.rotation.y = -(d.a + PI / 2)
	for av in avs:
		av.node.position = p3(av.x, av.y)
		av.node.get_node("Hull").rotation.y = -av.ha
		var atur: Node3D = av.node.get_node("Turret")
		atur.rotation.y = -av.ta
		atur.position = Vector3(0, 1.1 if av.k == "tk" else 0.9, 0) - Vector3(cos(av.ta), 0, sin(av.ta)) * 0.32 * av.rec
	for k in kamis:
		k.node.position = p3(k.x, k.y, 1.3)
		k.node.rotation = Vector3(0, -k.a, -0.35)
	for i in squad.size():
		var m: Dictionary = squad[i]
		m.node.position = p3(m.x, m.y)
		m.node.rotation.y = -m.face
		m.node.visible = ext.state != "leave" and m.down <= 0
		AC.walk(m.node, t * 11.0 + i * 1.7, 1.0 if m.mv else 0.0)
	for mn in mines:
		mn.node.get_node("Led").visible = mn.arm > 0 or int(t * 3) % 2 == 0
	for s in mis:
		s.node.visible = s.d <= 0
		s.node.position = p3(s.x, s.y, s.alt)
		s.node.rotation = Vector3(0, -s.a, -0.35 if s.alt < 14.0 else 0.0)
	for l in lobs:
		var k: float = l.t / l.d
		var lh: float = l.get("hgt", 5.0)
		l.node.position = p3(lerpf(l.x0, l.x1, k), lerpf(l.y0, l.y1, k), 0.6 + sin(k * PI) * lh)
		if l.has("hgt"):
			## 탄체가 나아가는 방향을 본다 (올라갈 때는 위로, 떨어질 때는 아래로)
			var hd = Vector2(l.x1 - l.x0, l.y1 - l.y0)
			l.node.rotation = Vector3(0, -hd.angle(), atan2(cos(k * PI) * lh * PI, hd.length() * K))
	for c in calls:
		if c.node:
			var k: float = c.t / c.max
			c.node.get_node("Beam").visible = int(t * 8) % 2 == 0 or k > 0.3
		if c.pod:
			var k: float = c.t / c.max
			var f = clampf(k / 0.45, 0.0, 1.0)
			c.pod.visible = k < 0.45
			c.pod.position = p3(c.x, c.y, f * 45.0)
	## 경보 경광등: 단말기 위에서 붉은 빛이 돈다
	if siren_light == null:
		siren_light = OmniLight3D.new()
		siren_light.light_color = Color("#ff2a1a")
		siren_light.omni_range = 16.0
		add_child(siren_light)
	siren_light.visible = sirenT > 0
	if sirenT > 0:
		siren_light.position = p3(siren_at.x + cos(t * 7.0) * 30, siren_at.y + sin(t * 7.0) * 30, 3.2)
		siren_light.light_energy = 5.0 * (0.55 + 0.45 * sin(t * 14.0)) * minf(1.0, sirenT)
	## 탈출 신호탄: 1.1초 동안 솟아오른 뒤 상공에서 일렁인다
	if flare_node != null and flareT >= 0:
		flareT += raw
		var fk = clampf(flareT / 1.1, 0.0, 1.0)
		var fh = 1.5 + (1.0 - (1.0 - fk) * (1.0 - fk)) * 20.0 + sin(t * 1.3) * 0.4
		flare_node.position = p3(flare_node.get_meta("x") + flareT * 3.0, flare_node.get_meta("y"), fh)
		var pulse = 1.0 + 0.2 * sin(t * 23.0) + (0.8 if fk >= 1.0 and flareT < 1.5 else 0.0)
		flare_node.get_node("Halo").scale = Vector3.ONE * pulse * (0.5 + 0.5 * fk)
		flare_node.get_node("Light").light_energy = 4.0 * pulse
		flare_node.visible = ext.state == "wait" or ext.state == "land"
		if fk < 1.0 and pt.size() < 390:
			pt.append({x = flare_node.get_meta("x") + flareT * 3.0, y = flare_node.get_meta("y"), vx = (randf() - 0.5) * 20, vy = (randf() - 0.5) * 20, t = 0.0, d = 0.7, c = Color("#ffb0a0"), r = 2.5, g = 3.0, h = fh, glow = true})
	## 탈출 헬기
	if heli_node:
		## 접근(26 m) → 제자리 비행(약 9 m) → 착륙(1.6 m) → 탑승 뒤 급상승하며 앞으로 빠져나간다
		var k: float = ext.ship
		var alt = (1.0 - k) * 26.0 + 1.6
		var fwd = 0.0
		if ext.state == "leave":
			var ok: float = ext.out * ext.out
			alt = 1.6 + ok * 34.0
			fwd = ok * 46.0
			heli_node.rotation.x = -0.28 * minf(1.0, ext.out * 2.0)
		else:
			heli_node.rotation.x = 0.06 * sin(t * 1.4) * (1.0 - k)
		heli_node.position = p3(ext.x, ext.y, alt) + Vector3(0, 0, -fwd)
		heli_node.get_node("Rotor").rotation.y += raw * 22.0
		heli_node.get_node("TailRotor").rotation.x += raw * 30.0
		heli_node.get_node("Beacon").visible = int(t * 4) % 2 == 0
	_draw_overlay()
	_draw_tracers()
	_draw_bars()
	_draw_particles()
	_draw_fx()
	for f in fl:
		f.lb.position = p3(f.x, f.y, 3.0 + f.t * 1.6)
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
	## 부대원이 여는 탈출로: 그 방향으로 초록 부채꼴
	if breakout != null:
		var bk: float = 0.7 + 0.3 * sin(t * 9)
		_ov_fan(p.x, p.y, 250, breakout.a, 0.39, Color(0.5, 0.88, 0.63, 0.13 * bk))
		_ov_ring(p.x, p.y, 250, 0.2, Color(0.5, 0.88, 0.63, 0.75 * bk), false, breakout.a - 0.39, 0.78, 12)
	## 방공포 교란 구역
	for o in map.objs:
		if o.type == "aa" and not o.done and stage < 3 and d2(o, p) < AAR + 600:
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
		if e.st == "alert" or e.st == "call" or e.type == "sn" or d2(e, p) > 460:
			continue
		var aw = clampf(e.aw, 0, 1)
		var col = Color(1, 1, 1, 0.09) if aw <= 0.02 else Color(1, (200 - aw * 160) / 255.0, 0.16, 0.12 + aw * 0.22)
		_ov_fan(e.x, e.y, e.T.vis, e.face, 0.85, col)
	## 전차 조준선
	for e in en:
		if e.aimT > 0 and d2(e, p) < 700:
			var bl = 0.35 + 0.45 * (1.0 - e.aimT / 0.7)
			_ov_rect(e.x, e.y, e.aimA, 50, 430, 1.4, Color(1, 0.2, 0.14, bl))
	## 순항 미사일: 표적 표시 + 지면 그림자
	for s in mis:
		if s.d > 0:
			continue
		var mr: float = 70 * p.m.blast
		_ov_disc(s.tx, s.ty, mr, Color(1, 0.3, 0.3, 0.1 + 0.08 * sin(t * 18)), 24)
		_ov_ring(s.tx, s.ty, mr, 0.25, Color(1, 0.3, 0.3, 0.9), true, t * 2.0, TAU, 24)
		_ov_rect(s.x + 10, s.y + 6, s.a, -12, 12, 3.0, Color(0, 0, 0, 0.3))
	## 거치 기관총: 올라탈 자리
	for tu in turrets:
		if tu.k == "hmg":
			_ov_ring(tu.x, tu.y, 30, 0.14, Color(0.86, 0.74, 0.4, 0.9 if is_same(p.mount, tu) else 0.5), true, t * 0.6, TAU, 20)
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
		if z.k == "smoke":
			_ov_disc(z.x, z.y, z.r, Color(0.78, 0.8, 0.82, 0.3 * al), 36)
			_ov_ring(z.x, z.y, z.r, 0.2, Color(0.85, 0.87, 0.9, 0.7 * al), true, 0.0, TAU, 36)
		elif z.k == "fire":
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
		var wing = 30.0 if j.big else 17.0
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
		if l.has("hgt"):
			## 날아오는 포탄의 지면 그림자
			var sk: float = clampf(l.t / l.d, 0.0, 1.0)
			_ov_disc(lerpf(l.x0, l.x1, sk) + 6, lerpf(l.y0, l.y1, sk) + 4, 5.0 + 4.0 * sk, Color(0, 0, 0, 0.18 + 0.2 * sk), 10)
			continue
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


## 끝이 뾰족한 빛줄기: 꼬리(x0,y0)는 투명한 점, 머리(x1,y1) 바로 뒤가 가장 굵고 머리 끝에서 다시 모인다
func _tr_taper(x0: float, y0: float, x1: float, y1: float, h: float, w: float, c_tail: Color, c_head: Color, neck := 0.88) -> void:
	var a = p3(x0, y0, h)
	var b = p3(x1, y1, h)
	var d = b - a
	if d.length() < 0.001:
		return
	var n = Vector3(-d.z, 0, d.x).normalized() * w * 0.5
	var m = a + d * neck
	tracer_im.surface_set_color(c_tail)
	tracer_im.surface_add_vertex(a)
	tracer_im.surface_set_color(c_head)
	tracer_im.surface_add_vertex(m - n)
	tracer_im.surface_add_vertex(m + n)
	tracer_im.surface_add_vertex(m - n)
	tracer_im.surface_add_vertex(m + n)
	tracer_im.surface_add_vertex(b)


## 예광탄: 탄속에 비례한 긴 궤적(len_s초 분량)이 꼬리로 갈수록 가늘어지며 사라진다.
## 옅은 번짐 + 색 궤적 + 흰 심 세 겹. 궤적이 총구 뒤로 넘어가지 않게 쏜 자리까지만 그린다
func _tr_streak(b: Dictionary, h: float, len_s: float, w: float, col: Color, glow := 1.0) -> void:
	var sp: float = Vector2(b.vx, b.vy).length()
	if sp < 1.0:
		return
	if not b.has("sx"):
		b.sx = b.x
		b.sy = b.y
	var L: float = minf(clampf(sp * len_s, 20.0, 80.0), Vector2(b.x - b.sx, b.y - b.sy).length())
	if L < 2.0:
		return
	var ux: float = b.vx / sp
	var uy: float = b.vy / sp
	_tr_taper(b.x - ux * L, b.y - uy * L, b.x, b.y, h, w * 3.2, Color(col, 0.0), Color(col, 0.16 * glow))
	_tr_taper(b.x - ux * L, b.y - uy * L, b.x, b.y, h + 0.01, w, Color(col, 0.0), Color(col, 0.85))
	_tr_taper(b.x - ux * L * 0.5, b.y - uy * L * 0.5, b.x, b.y, h + 0.02, w * 0.42, Color(1, 0.97, 0.88, 0.0), Color(1, 0.97, 0.88, 1.0))


func _draw_tracers() -> void:
	tracer_im.clear_surfaces()
	tracer_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	tracer_im.surface_add_vertex(Vector3.ZERO)
	tracer_im.surface_add_vertex(Vector3.ZERO)
	tracer_im.surface_add_vertex(Vector3.ZERO)
	var bc = Color("#ff6a1a") if p.evo.has("sg") else Color("#7fe3ff") if p.evo.has("rail") else Color("#ffb03a")
	var wc = wcol()
	var pellet: bool = p.w.id == "sg" and p.mount == null
	for b in bul:
		var bh: float = b.get("h", LIFT)
		if b.get("evo", false):
			## 진화 탄: 굵고 긴 색 궤적
			_tr_streak(b, bh, 0.11, 0.2, wc, 1.5)
			continue
		_tr_streak(b, bh, 0.05 if pellet else 0.085, 0.07 if pellet else 0.1, bc)
	## 총구 화염: 쏜 순간에만 앞으로 짧게 뻗는 불꽃과 옆으로 새는 가스
	if p.muz > 0 and ext.state != "leave":
		var mounted: bool = p.mount != null
		var mz: Vector2 = muzzle(p.mount.x if mounted else p.x, p.mount.y if mounted else p.y, p.aim, 26.0 if mounted else 20.0, 0.0 if mounted else 2.6)
		var fk: float = clampf(p.muz / 0.05, 0.0, 1.0)
		var fs: float = (1.5 if mounted or p.w.id == "sg" or p.w.id == "lmg" else 0.8) * (0.7 + 0.3 * randf())
		var fh: float = 1.02 if mounted else LIFT
		var fc := Color(1.0, 0.78, 0.4, 0.9 * fk)
		for fa in [0.0, 1.25, -1.25]:
			var fl_len: float = (11.0 if fa == 0.0 else 4.5) * fs
			_tr_taper(mz.x + cos(p.aim + fa) * fl_len, mz.y + sin(p.aim + fa) * fl_len, mz.x, mz.y, fh + 0.02, 0.22 * fs if fa == 0.0 else 0.1 * fs, Color(fc, 0.0), fc, 0.75)
	for bm in beams:
		var k: float = 1.0 - bm.t / bm.d
		_tr_seg(bm.x0, bm.y0, bm.x1, bm.y1, LIFT, bm.w * (0.4 + 0.6 * k), Color(bm.c, 0.7 * k))
		_tr_seg(bm.x0, bm.y0, bm.x1, bm.y1, LIFT + 0.01, bm.w * 0.3 * k, Color(1, 1, 1, k))
	for b in eb:
		if b.get("shell", false):
			_tr_streak(b, 1.4, 0.1, 0.24, Color(1, 0.55, 0.15), 1.4)
			continue
		if b.get("ac", false):
			## 기관포탄: 보병 탄보다 굵고 낮게 (포탑 높이)
			_tr_streak(b, 1.15, 0.11, 0.15, Color(1, 0.45, 0.12), 1.2)
			continue
		_tr_streak(b, LIFT, 0.1, 0.1, Color(1, 0.23, 0.1))
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
		var r0 = 0.8
		var r1 = 0.94
		var q = [c + Vector3(cos(a0) * r0, 0, sin(a0) * r0), c + Vector3(cos(a0) * r1, 0, sin(a0) * r1), c + Vector3(cos(a1) * r1, 0, sin(a1) * r1), c + Vector3(cos(a1) * r0, 0, sin(a1) * r0)]
		bar_im.surface_set_color(Color(0.86, 0.74, 0.4, 0.4))
		for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			bar_im.surface_add_vertex(v)
	var top = p3(p.x, p.y, 3.25)
	var r = cam.global_basis.x * 0.22
	var u = cam.global_basis.y * 0.3
	bar_im.surface_set_color(Color(0.86, 0.74, 0.4, 0.8))
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
		if (e.T.has("armor") or e.type == "sh") and e.hp < e.maxhp and e.node.visible:
			_bar(p3(e.x, e.y, 3.3 if e.T.has("armor") else 2.9), 1.8 if e.T.has("armor") else 1.1, clampf(e.hp / e.maxhp, 0, 1), red)
	for o in map.objs:
		if is_dest(o) and not o.done and o.hp < o.maxhp:
			_bar(p3(o.x, o.y, {nest = 5.2, jam = 6.4, fac = 6.6}.get(o.type, 4.0)), 3.0, clampf(o.hp / o.maxhp, 0, 1), red)
	for tu in turrets:
		_bar(p3(tu.x, tu.y, 1.9), 1.2, tu.life / tu.max, Color("#4fa3d9"))
	## 다친 부대원·드론
	for m in squad:
		if m.down <= 0 and m.hp < m.maxhp:
			_bar(p3(m.x, m.y, 2.7), 0.9, clampf(m.hp / m.maxhp, 0, 1), Color("#4fa3d9"))
	for d in drones:
		if d.down <= 0 and d.hp < d.maxhp:
			_bar(p3(d.x, d.y, 2.3), 0.7, clampf(d.hp / d.maxhp, 0, 1), Color("#4fa3d9"))
	if p.reload > 0:
		_bar(p3(p.x, p.y, 2.85), 1.0, 1.0 - p.reload / (p.w.reload * p.m.rl), Color("#f2c21b"))
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
		mi.position = p3(f.x, f.y, f.get("h", f.r * K * (0.2 + 0.4 * k)))
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
