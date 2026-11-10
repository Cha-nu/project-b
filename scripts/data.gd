extends RefCounted
## 게임 데이터 (HTML 프로토타입 index.html의 데이터 구역을 옮긴 것)
## 좌표·거리·속도는 프로토타입과 같은 "게임 단위"를 쓴다. 3D로 그릴 때 Game.K(미터/단위)를 곱한다.

const WEAPONS := [
	{id = "ar", name = "돌격소총", desc = "소음기 장착. 균형 잡힌 표준 화기", rate = 7.0, dmg = 11.0, speed = 520.0, spread = 0.06, mag = 30, reload = 1.3, pellets = 1, pierce = 0, range = 290.0, kb = 20.0, noise = 110.0},
	{id = "sg", name = "산탄총", desc = "근거리 광역, 강한 넉백. 시끄럽다", rate = 1.5, dmg = 11.0, speed = 470.0, spread = 0.55, mag = 6, reload = 1.6, pellets = 7, pierce = 0, range = 185.0, kb = 150.0, noise = 330.0},
	{id = "lmg", name = "경기관총", desc = "탄막 제압, 긴 재장전. 시끄럽다", rate = 13.0, dmg = 7.0, speed = 520.0, spread = 0.2, mag = 90, reload = 2.6, pellets = 1, pierce = 0, range = 290.0, kb = 12.0, noise = 300.0},
	{id = "rail", name = "레일건", desc = "관통과 장갑 무시, 느린 연사", rate = 1.1, dmg = 75.0, speed = 900.0, spread = 0.0, mag = 5, reload = 1.8, pellets = 1, pierce = 6, range = 400.0, kb = 60.0, ap = true, noise = 230.0},
]

## aim: pt=지점, line=방향 슬라이드, near=근처 배치, ""=즉시
const STRATS := [
	{id = "air", name = "정밀 공습", code = ".-..", cd = 14.0, rar = 0, price = 0, aim = "line", n = 3, gap = 62.0, rad = 75.0, desc = "슬라이드한 방향으로 폭탄 3발을 일렬 투하합니다."},
	{id = "supply", name = "보급 투하", code = "..-", cd = 25.0, rar = 0, price = 0, aim = "near", rad = 45.0, desc = "보급 상자를 떨어뜨립니다. 체력 45% 회복, 8초간 속사."},
	{id = "turret", name = "센트리 건", code = "-.-", cd = 28.0, rar = 0, price = 0, aim = "near", rad = 48.0, desc = "20초 동안 자동 사격하는 포탑을 투하합니다."},
	{id = "strafe", name = "기총소사", code = "....", cd = 10.0, rar = 0, price = 150, aim = "line", n = 10, gap = 34.0, rad = 40.0, desc = "슬라이드한 방향으로 길게 긁고 지나갑니다. 재사용이 빠릅니다."},
	{id = "mines", name = "지뢰 살포", code = "--.", cd = 20.0, rar = 0, price = 150, aim = "near", rad = 110.0, desc = "지정한 곳에 지뢰 10개를 뿌립니다."},
	{id = "napalm", name = "네이팜", code = "-..-", cd = 22.0, rar = 1, price = 300, aim = "line", n = 5, gap = 58.0, rad = 55.0, desc = "슬라이드한 방향으로 7초간 불타는 화염 띠를 만듭니다."},
	{id = "shield", name = "방호 장막", code = ".--.", cd = 26.0, rar = 1, price = 300, aim = "", desc = "즉시 발동. 6초 무적과 주변을 밀어내는 충격파."},
	{id = "heal", name = "의무 지원", code = ".---", cd = 30.0, rar = 1, price = 300, aim = "near", rad = 85.0, desc = "8초간 안에 서 있으면 체력이 차오르는 치료 구역."},
	{id = "stun", name = "섬광 충격탄", code = "-...-", cd = 20.0, rar = 1, price = 350, aim = "pt", rad = 140.0, desc = "넓은 범위의 적을 4.5초간 기절시킵니다."},
	{id = "carpet", name = "융단 포격", code = "---.", cd = 30.0, rar = 2, price = 600, aim = "pt", rad = 190.0, desc = "넓은 구역에 포탄 14발을 연속으로 쏟아붓습니다."},
	{id = "drone", name = "공격 드론", code = "-....", cd = 35.0, rar = 2, price = 600, aim = "", desc = "즉시 발동. 20초간 드론 2기가 따라다니며 사격합니다."},
	{id = "mortar", name = "박격포 진지", code = ".-.--", cd = 30.0, rar = 2, price = 650, aim = "near", rad = 48.0, desc = "16초 동안 적 밀집 지점을 계속 포격하는 박격포."},
	{id = "missiles", name = "유도 미사일", code = "...-.", cd = 26.0, rar = 2, price = 700, aim = "", desc = "즉시 발동. 체력이 높은 적 6기를 추적합니다. 전차 사냥용."},
	{id = "gunship", name = "건십 지원", code = ".-.-.", cd = 45.0, rar = 3, price = 1200, aim = "pt", rad = 60.0, desc = "8초간 상공의 건십이 적을 쫓아가며 포격합니다."},
	{id = "thermo", name = "열압력탄", code = "----.", cd = 40.0, rar = 3, price = 1200, aim = "pt", rad = 190.0, desc = "주변 적을 3.5초간 빨아들인 뒤 대폭발합니다."},
	{id = "moab", name = "초대형 폭탄", code = "-----.", cd = 80.0, rar = 3, price = 2000, aim = "pt", rad = 270.0, desc = "4초 뒤 화면 전체급 폭발. 아군 피해가 큽니다. 도망치세요."},
]
const SOS := "...---..."
const RAR := ["일반", "희귀", "영웅", "전설"]
const RAR_COL := [Color("#9aa09c"), Color("#4fa3d9"), Color("#b07ce0"), Color("#f2c21b")]
const AIMN := {pt = "지점 지정", line = "방향 슬라이드", near = "근처 배치"}

const UPS := [
	{id = "dmg", n = "고폭탄", t = "ATK", max = 5, d = "총기 공격력 +18%"},
	{id = "rate", n = "속사 장치", t = "RPM", max = 5, d = "연사 속도 +12%"},
	{id = "pierce", n = "철갑탄", t = "AP", max = 3, d = "탄환 관통 +1"},
	{id = "mag", n = "대용량 탄창", t = "MAG", max = 4, d = "탄창 +30%, 재장전 -10%"},
	{id = "multi", n = "이중 총열", t = "x2", max = 2, d = "발사체 +1"},
	{id = "spd", n = "강화 군화", t = "SPD", max = 4, d = "이동 속도 +8%"},
	{id = "hp", n = "방탄판", t = "HP", max = 5, d = "최대 체력 +20, 30 회복"},
	{id = "magnet", n = "수거 장치", t = "MGT", max = 3, d = "경험치 획득 범위 +40%"},
	{id = "cd", n = "통신 증폭기", t = "CDR", max = 5, d = "지원요청 재사용 -8%"},
	{id = "blast", n = "대형 탄두", t = "BLT", max = 5, d = "폭발 반경과 피해 +12%"},
	{id = "gren", n = "수류탄 투척", t = "GRN", max = 5, sub = true, d = "자동으로 적 밀집 지점에 수류탄을 던집니다"},
	{id = "drone", n = "호위 드론", t = "DRN", max = 5, sub = true, d = "주위를 돌며 사격하는 드론 (Lv4에 2기)"},
	{id = "taser", n = "테이저 방전", t = "TSR", max = 5, sub = true, d = "가까운 적 여럿에게 전기 충격"},
]
const EVOS := [
	{id = "ar", w = "ar", n = "스마트 소총", d = "탄환이 명중 후 다른 적에게 2번 도탄합니다", need = {rate = 3, pierce = 2}},
	{id = "sg", w = "sg", n = "용의 숨결", d = "산탄 +4발, 맞은 적이 불탑니다", need = {multi = 2, dmg = 3}},
	{id = "lmg", w = "lmg", n = "미니건", d = "재장전 없음, 연사 +50%", need = {mag = 3, rate = 3}},
	{id = "rail", w = "rail", n = "플라즈마 레일", d = "무한 관통, 명중할 때마다 폭발", need = {pierce = 2, blast = 3}},
	{id = "gren", sub = "gren", n = "집속 수류탄", d = "폭발 후 자탄 4개가 추가로 터집니다", need = {gren = 3, blast = 3}},
	{id = "drone", sub = "drone", n = "드론 편대", d = "드론 +2기, 드론 연사 +60%", need = {drone = 3, rate = 3}},
	{id = "comms", any = true, n = "통신 드론", d = "드론이 장착한 지원요청을 상황에 맞게 자동 호출합니다. 재사용 대기는 플레이어와 별도", need = {cd = 3, blast = 2}},
	{id = "taser", sub = "taser", n = "폭풍 방전", d = "범위 안 모든 적을 감전시키고 잠깐 기절", need = {taser = 3, cd = 3}},
]
## vis: 시야 거리
const ET := {
	ru = {hp = 20.0, spd = 76.0, r = 9.0, dmg = 3.0, xp = 1, vis = 160.0},
	sh = {hp = 140.0, spd = 46.0, r = 13.0, dmg = 8.0, xp = 4, vis = 150.0},
	rf = {hp = 45.0, spd = 55.0, r = 10.0, dmg = 6.0, xp = 3, ranged = true, vis = 200.0},
	dr = {hp = 10.0, spd = 128.0, r = 7.0, dmg = 12.0, xp = 2, fly = true, vis = 180.0},
	tk = {hp = 900.0, spd = 32.0, r = 24.0, dmg = 22.0, xp = 0, armor = 0.4, vis = 230.0},
}
const BIOMES := [
	{n = "사막 시가지", g = ["#b48a5c", "#a98052", "#9c7449", "#bf9668"], road = "#4d4740", roadE = "#8f7552", lane = "#d8c690", rock = "#9a8466", deco = "#7d6a3e",
		sun = "#ffe2b8", amb = "#c9a27a", sky = "#d9b48a", fog = "#c8a074",
		kinds = [["bld", 40], ["car", 12], ["cont", 10], ["sand", 12], ["palm", 14], ["rock", 12]], roof = ["#b9ad97", "#a69a84", "#c4b8a0", "#9b8e78"], wall = ["#8a7d68", "#7a6e5a", "#958870", "#6f6452"]},
	{n = "산림 마을", g = ["#56663b", "#4d5d35", "#43522e", "#617144"], road = "#5e5240", roadE = "#4a4630", lane = "", rock = "#808a86", deco = "#7f9a52",
		sun = "#f0f0dc", amb = "#7a8a70", sky = "#9fb3a0", fog = "#8a9a84",
		kinds = [["tree", 44], ["pine", 12], ["rock", 14], ["bld", 14], ["car", 8], ["sand", 8]], roof = ["#6b3a2e", "#4f4a44", "#7a4a36", "#3d4448"], wall = ["#a39b88", "#8f8878", "#b0a690", "#7d776a"]},
	{n = "설원 기지", g = ["#d3d9de", "#c7cfd6", "#b8c2cb", "#e1e6ea"], road = "#565c63", roadE = "#9aa4ad", lane = "#e8d36a", rock = "#8d99a6", deco = "#a8b8c8", snow = true,
		sun = "#e8f0ff", amb = "#8a9ab8", sky = "#b8c8dc", fog = "#c0ccd8",
		kinds = [["pine", 40], ["rock", 16], ["cont", 14], ["bld", 18], ["sand", 12]], roof = ["#e8edf0", "#dfe5ea", "#d6dde3"], wall = ["#5a6470", "#6b5048", "#4f5a4a"]},
]

static func strat(id: String) -> Dictionary:
	for s in STRATS:
		if s.id == id:
			return s
	return {}

static func weapon(id: String) -> Dictionary:
	for w in WEAPONS:
		if w.id == id:
			return w
	return WEAPONS[0]

static func up_name(id: String) -> String:
	for u in UPS:
		if u.id == id:
			return u.n
	return id
