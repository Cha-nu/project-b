extends RefCounted
## 게임 데이터 (HTML 프로토타입 index.html의 데이터 구역을 옮긴 것)
## 좌표·거리·속도는 프로토타입과 같은 "게임 단위"를 쓴다. 3D로 그릴 때 Game.K(미터/단위)를 곱한다.

## 무기: 계열(id) 4종 x 등급(tier) 3단계. wid가 상점·저장용 고유 이름이고, id는 계열이다
## (진화·아이콘·전투 로직은 전부 계열 id로 본다). 같은 계열이라도 등급이 높을수록 성능이 좋다
const WEAPONS := [
	{wid = "ar1", id = "ar", tier = 1, price = 0, name = "돌격소총", desc = "소음기 장착. 균형 잡힌 표준 화기", rate = 7.0, dmg = 11.0, speed = 520.0, spread = 0.06, mag = 30, reload = 1.3, pellets = 1, pierce = 0, range = 290.0, kb = 20.0, noise = 110.0},
	{wid = "ar2", id = "ar", tier = 2, price = 500, name = "개량 돌격소총", desc = "총열과 방아쇠를 손본 개량형. 더 빠르고 정확하다", rate = 7.8, dmg = 12.5, speed = 540.0, spread = 0.05, mag = 32, reload = 1.15, pellets = 1, pierce = 0, range = 305.0, kb = 22.0, noise = 105.0},
	{wid = "ar3", id = "ar", tier = 3, price = 1500, name = "특수전 소총", desc = "특수부대용 정밀 소총. 조용하고 치명적이다", rate = 8.6, dmg = 14.5, speed = 560.0, spread = 0.04, mag = 36, reload = 1.0, pellets = 1, pierce = 1, range = 320.0, kb = 24.0, noise = 90.0},
	{wid = "sg1", id = "sg", tier = 1, price = 300, name = "산탄총", desc = "근거리 광역, 강한 넉백. 시끄럽다", rate = 1.5, dmg = 11.0, speed = 470.0, spread = 0.55, mag = 6, reload = 1.6, pellets = 7, pierce = 0, range = 185.0, kb = 150.0, noise = 330.0},
	{wid = "sg2", id = "sg", tier = 2, price = 800, name = "전투 산탄총", desc = "탄창이 늘고 재장전이 빨라진 전투형", rate = 1.8, dmg = 12.5, speed = 480.0, spread = 0.5, mag = 8, reload = 1.4, pellets = 7, pierce = 0, range = 195.0, kb = 160.0, noise = 330.0},
	{wid = "sg3", id = "sg", tier = 3, price = 1800, name = "자동 산탄총", desc = "연발로 쏟아붓는 자동식. 산탄도 한 발 더", rate = 2.4, dmg = 13.5, speed = 490.0, spread = 0.5, mag = 10, reload = 1.3, pellets = 8, pierce = 0, range = 200.0, kb = 165.0, noise = 340.0},
	{wid = "lmg1", id = "lmg", tier = 1, price = 500, name = "경기관총", desc = "탄막 제압, 긴 재장전. 시끄럽다", rate = 13.0, dmg = 7.0, speed = 520.0, spread = 0.2, mag = 90, reload = 2.6, pellets = 1, pierce = 0, range = 290.0, kb = 12.0, noise = 300.0},
	{wid = "lmg2", id = "lmg", tier = 2, price = 1000, name = "분대 기관총", desc = "탄통이 커지고 탄 퍼짐이 줄었다", rate = 14.5, dmg = 8.0, speed = 540.0, spread = 0.17, mag = 110, reload = 2.3, pellets = 1, pierce = 0, range = 300.0, kb = 13.0, noise = 300.0},
	{wid = "lmg3", id = "lmg", tier = 3, price = 2200, name = "중기관총", desc = "굵은 탄이 한 명을 뚫고 지나간다", rate = 15.5, dmg = 9.5, speed = 560.0, spread = 0.15, mag = 140, reload = 2.1, pellets = 1, pierce = 1, range = 310.0, kb = 16.0, noise = 310.0},
	{wid = "rail1", id = "rail", tier = 1, price = 800, name = "레일건", desc = "관통과 장갑 무시, 느린 연사", rate = 1.1, dmg = 75.0, speed = 900.0, spread = 0.0, mag = 5, reload = 1.8, pellets = 1, pierce = 6, range = 400.0, kb = 60.0, ap = true, noise = 230.0},
	{wid = "rail2", id = "rail", tier = 2, price = 1500, name = "가속 레일건", desc = "축전기를 키워 더 세고 더 빨리 쏜다", rate = 1.3, dmg = 90.0, speed = 950.0, spread = 0.0, mag = 6, reload = 1.6, pellets = 1, pierce = 7, range = 415.0, kb = 65.0, ap = true, noise = 230.0},
	{wid = "rail3", id = "rail", tier = 3, price = 3000, name = "초전도 레일건", desc = "전차도 한두 발. 사거리가 가장 길다", rate = 1.5, dmg = 110.0, speed = 1000.0, spread = 0.0, mag = 7, reload = 1.4, pellets = 1, pierce = 8, range = 430.0, kb = 70.0, ap = true, noise = 240.0},
]
const WCLASS := {ar = "돌격소총 계열", sg = "산탄총 계열", lmg = "기관총 계열", rail = "레일건 계열"}

## aim: pt=지점, line=방향 슬라이드, near=근처 배치, ""=즉시
const STRATS := [
	{id = "air", name = "정밀 공습", code = ".-..", cd = 14.0, rar = 0, price = 0, aim = "line", n = 3, gap = 62.0, rad = 75.0, desc = "슬라이드한 방향으로 폭탄 3발을 일렬 투하합니다."},
	{id = "supply", name = "보급 투하", code = "..-", cd = 25.0, rar = 0, price = 0, aim = "near", rad = 45.0, desc = "보급 상자를 떨어뜨립니다. 체력 45% 회복, 8초간 속사."},
	{id = "turret", name = "센트리 건", code = "-.-", cd = 28.0, rar = 0, price = 0, aim = "near", rad = 48.0, desc = "20초 동안 자동 사격하는 포탑을 투하합니다."},
	{id = "strafe", name = "기총소사", code = "....", cd = 10.0, rar = 0, price = 150, aim = "line", n = 10, gap = 34.0, rad = 40.0, desc = "슬라이드한 방향으로 길게 긁고 지나갑니다. 재사용이 빠릅니다."},
	{id = "mines", name = "지뢰 살포", code = "--.", cd = 20.0, rar = 0, price = 150, aim = "near", rad = 110.0, desc = "지정한 곳에 지뢰 10개를 뿌립니다."},
	{id = "smoke", name = "연막 차장", code = ".-.", cd = 22.0, rar = 0, price = 200, aim = "near", rad = 150.0, desc = "연막탄 포격으로 12초간 연막을 깝니다. 연막 안에 있으면 적이 보지 못합니다."},
	{id = "napalm", name = "네이팜", code = "-..-", cd = 22.0, rar = 1, price = 300, aim = "line", n = 5, gap = 58.0, rad = 55.0, desc = "슬라이드한 방향으로 7초간 불타는 화염 띠를 만듭니다."},
	{id = "shield", name = "방호 장막", code = ".--.", cd = 26.0, rar = 1, price = 300, aim = "", desc = "즉시 발동. 6초 무적과 주변을 밀어내는 충격파."},
	{id = "heal", name = "의무 지원", code = ".---", cd = 30.0, rar = 1, price = 300, aim = "near", rad = 85.0, desc = "8초간 안에 서 있으면 체력이 차오르는 치료 구역."},
	{id = "stun", name = "섬광 충격탄", code = "-...-", cd = 20.0, rar = 1, price = 350, aim = "pt", rad = 140.0, desc = "넓은 범위의 적을 4.5초간 기절시킵니다."},
	{id = "sniper", name = "저격 지원", code = "..--", cd = 28.0, rar = 1, price = 350, aim = "", desc = "즉시 발동. 15초 동안 원거리 저격수가 위협이 큰 적부터 한 명씩 제거합니다."},
	{id = "sat", name = "위성 정찰", code = "..-.", cd = 35.0, rar = 1, price = 300, aim = "", desc = "즉시 발동. 30초 동안 미니맵에 모든 적이 표시됩니다."},
	{id = "carpet", name = "융단 포격", code = "---.", cd = 30.0, rar = 2, price = 600, aim = "pt", rad = 190.0, desc = "넓은 구역에 포탄 14발을 연속으로 쏟아붓습니다."},
	{id = "hmg", name = "거치 기관총", code = "-....", cd = 35.0, rar = 2, price = 600, aim = "near", rad = 48.0, desc = "기관총 진지를 투하합니다. 25초 동안 올라타 있으면 주무기 대신 관통 중기관총을 난사합니다."},
	{id = "apache", name = "공격헬기", code = "-.--", cd = 45.0, rar = 2, price = 900, aim = "", desc = "즉시 발동. 25초 동안 공격헬기가 상공을 따라다니며 기관포를 퍼붓고 4초마다 로켓 4발을 쏩니다."},
	{id = "ltank", name = "경전차 지원", code = "-..", cd = 50.0, rar = 2, price = 800, aim = "near", rad = 48.0, desc = "아군 경전차를 투하합니다. 30초 동안 따라다니며 기관포 3점사로 보병을 쓸어 냅니다."},
	{id = "tank", name = "전차 지원", code = "--..", cd = 70.0, rar = 3, price = 1800, aim = "near", rad = 48.0, desc = "아군 전차를 투하합니다. 35초 동안 따라다니며 주포로 기갑과 밀집한 적을 부수고 기관총을 쏩니다."},
	{id = "mortar", name = "박격포 진지", code = ".-.--", cd = 30.0, rar = 2, price = 650, aim = "near", rad = 48.0, desc = "16초 동안 적 밀집 지점을 계속 포격하는 박격포."},
	{id = "missiles", name = "순항 미사일", code = "...-.", cd = 26.0, rar = 2, price = 700, aim = "", desc = "즉시 발동. 먼 곳에서 순항 미사일 4발이 날아와 체력이 높은 적을 추적해 크게 터집니다. 전차 사냥용."},
	{id = "emp", name = "전자전", code = "-.-.", cd = 40.0, rar = 2, price = 700, aim = "", desc = "즉시 발동. 20초 동안 적의 증원 요청을 막고 드론·전차·자주포를 멈춥니다."},
	{id = "naval", name = "함포 사격", code = "--.-", cd = 50.0, rar = 3, price = 1500, aim = "pt", rad = 150.0, desc = "3초 예고 뒤 초대형 포탄 3발이 차례로 떨어집니다. 아군 피해가 큽니다."},
	{id = "gunship", name = "건십 지원", code = ".-.-.", cd = 45.0, rar = 3, price = 1200, aim = "pt", rad = 60.0, desc = "8초간 상공의 건십이 적을 쫓아가며 포격합니다."},
	{id = "thermo", name = "열압력탄", code = "----.", cd = 40.0, rar = 3, price = 1200, aim = "pt", rad = 190.0, desc = "주변 적을 3.5초간 빨아들인 뒤 대폭발합니다."},
	{id = "moab", name = "초대형 폭탄", code = "-----.", cd = 80.0, rar = 3, price = 2000, aim = "pt", rad = 270.0, desc = "4초 뒤 화면 전체급 폭발. 아군 피해가 큽니다. 도망치세요."},
]
## 보스가 나오는 스테이지 → 보스 종류. 이 스테이지의 주 임무는 단말기 해킹 대신 보스 격파다
const BOSS := {5: "b1", 8: "b2", 10: "b3"}


## 적 종류가 처음 나오는 스테이지 (없는 것은 1부터). 아직 안 풀린 종류는 FALLBACK을 따라 아래 단계로 바뀐다
const UNLOCK := {rf = 2, lt = 2, sh = 3, dr = 4, tk = 5, sp = 6, sn = 7, ml = 8}
const FALLBACK := {sn = "rf", rf = "ru", sh = "rf", dr = "ru", tk = "lt", sp = "tk", ml = "sp", lt = ""}
const ENEMY_NAME := {ru = "돌격병", rf = "소총병", sh = "방패병", dr = "자폭 드론", lt = "경전차", tk = "전차", sp = "자주포", sn = "길리 저격수", ml = "미사일 발사대"}
## 보조 목표가 처음 나오는 스테이지 (통신탑은 1부터)
const OBJ_UNLOCK := {nest = 2, aa = 3, jam = 4, fac = 6}
const OBJ_NAME := {cap = "통신탑", nest = "적 부대", aa = "방공포", jam = "교란기", fac = "군수공장"}


## 그 스테이지에서 실제로 나올 적 종류. 안 풀렸으면 아래 단계로, 그것도 없으면 ""
static func unlocked(ty: String, stage: int) -> String:
	var t := ty
	while t != "" and stage < int(UNLOCK.get(t, 1)):
		t = FALLBACK.get(t, "")
	return t


static func stage_enemies(stage: int) -> Array:
	var a: Array = []
	for k in ["ru", "rf", "sh", "dr", "lt", "tk", "sp", "sn", "ml"]:
		if stage >= int(UNLOCK.get(k, 1)):
			a.append(ENEMY_NAME[k])
	return a


static func stage_objs(stage: int) -> Array:
	var a: Array = ["cap"]
	for k in ["nest", "aa", "jam", "fac"]:
		if stage >= OBJ_UNLOCK[k]:
			a.append(k)
	return a


## 그 스테이지에서 새로 나오는 것 (없으면 빈 문자열)
static func stage_new(stage: int) -> String:
	var a: Array = []
	for k in UNLOCK:
		if UNLOCK[k] == stage:
			a.append(ENEMY_NAME[k])
	for k in OBJ_UNLOCK:
		if OBJ_UNLOCK[k] == stage:
			a.append(OBJ_NAME[k])
	return " · ".join(a)


## 스테이지별 작전 브리핑. op: 작전명, sit: 이 구역이 왜 중요한가, order: 지휘부 지시
const BRIEF := [
	{op = "첫 신호", sit = "적 통신망의 말단 중계 거점. 본대 투입에 앞서 이곳 단말에서 적 배치 정보를 빼내야 전선의 눈이 뜨인다.", order = "은밀 침투 우선. 발각되면 증원이 붙는다. 교전은 짧게 끝내라."},
	{op = "긴 그림자", sit = "적 보급로가 만나는 교차 지점. 이곳의 수송 일정을 손에 넣으면 아군 포병이 보급 행렬을 끊을 수 있다.", order = "순찰조의 동선을 읽고 틈으로 들어가라. 무전병을 먼저 침묵시켜라."},
	{op = "닫힌 하늘", sit = "여기서부터 적 방공망의 우산 아래다. 방공 진지가 살아 있는 한 아군 항공 전력은 접근할 수 없다.", order = "항공 지원을 기대하지 마라. 방공포를 무력화하면 하늘이 열린다."},
	{op = "끊어진 선", sit = "전선 사령부와 후방을 잇는 통신 결절. 이 선이 끊기면 적 여단은 눈과 귀를 잃고 제각기 싸우게 된다.", order = "통신탑을 장악해 적 배치를 확보하라. 교란기가 지도를 흐릴 것이다."},
	{op = "강철 관문", sit = "기갑 부대가 집결하는 길목. 이 관문을 열지 못하면 아군 기계화 부대의 진격로가 막힌다.", order = "다포탑 중전차 「코뿔소」가 관문을 지킨다. 부포탑부터 떨어뜨리고, 대기갑 화력을 아껴 뒀다 쏟아부어라."},
	{op = "잿빛 수확", sit = "전선에 탄약과 차량을 대는 군수 거점. 공장이 도는 동안에는 적 증원에 기갑이 계속 섞여 나온다.", order = "군수공장을 멈춰라. 그 뒤라야 증원의 이빨이 빠진다."},
	{op = "깊은 종심", sit = "적 종심 깊숙한 지휘 구역. 아군 주력의 돌파 방향을 숨기려면 이곳의 지휘 단말을 먼저 무너뜨려야 한다.", order = "주 목표에도 전차가 붙었다. 연막과 전자전으로 접근로를 만들어라."},
	{op = "천둥 계곡", sit = "포병 여단의 사격 진지. 이 계곡의 포가 살아 있으면 아군 교두보 전체가 사정권에 든다.", order = "열차포 「천둥」이 맵 어디든 포탄을 떨군다. 탄착 예고를 보면 즉시 이탈하고, 방공망을 걷어낸 뒤 폭격으로 끝내라."},
	{op = "마지막 방벽", sit = "적 수도권으로 가는 최후 방어선. 이곳이 뚫리면 적은 더 물러설 곳이 없다. 저항은 필사적일 것이다.", order = "증원은 빠르고 크다. 목표를 끝내는 대로 지체 없이 탈출 지점으로 이동하라."},
	{op = "새벽 파도", sit = "적 최고 사령부의 통신 중추. 이곳을 장악하면 전쟁의 끝이 보인다. 아군 전 전력이 귀관의 신호를 기다린다.", order = "이동 지휘 요새 「성채」를 격파하라. 요새의 방공 포탑이 살아 있는 동안에는 항공 지원이 닿지 않는다. 모든 수단을 써라."},
]


## 지원요청 해금 트리: 계열마다 왼쪽부터 순서대로 사야 다음이 열린다
const BRANCHES := [
	{n = "공중 타격", d = "전투기·폭격기가 날아와 쏟아붓는다", ids = ["air", "strafe", "napalm", "carpet", "moab"]},
	{n = "포격·미사일", d = "먼 곳의 포대와 함정이 쏜다", ids = ["smoke", "mortar", "missiles", "naval", "thermo"]},
	{n = "거점 화력", d = "현장에 화기를 내려 진지를 만든다", ids = ["turret", "mines", "hmg", "gunship"]},
	{n = "기갑·항공 지원", d = "곁에 와서 함께 싸운다", ids = ["ltank", "apache", "tank"]},
	{n = "정보·전자전", d = "보고, 끊고, 멈춘다", ids = ["sat", "sniper", "stun", "emp"]},
	{n = "보급·방호", d = "버티게 해 준다", ids = ["supply", "heal", "shield"]},
]
## 지원요청 장착 칸: 기본 3칸, 네 번째 칸은 아주 비싸게 산다
const SLOT_MAX := 4
const SLOT_PRICE := 5000


## 그 스테이지를 깨는 데 필요한 장비 수준 (로비 브리핑에 띄운다). 적 체력 곡선(Game.hp_mul)과 맞춘 것
static func gear_hint(stage: int) -> String:
	if stage <= 2:
		return "기본 장비"
	if stage <= 5:
		return "2등급 무기 · 희귀 지원요청"
	if stage <= 7:
		return "2등급 무기 · 영웅 지원요청"
	return "3등급 무기 · 영웅·전설 지원요청"


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
	## dl: 레벨마다 따로 보여 줄 설명 (그 레벨에서 새로 붙는 것). tag: 처음 얻을 때 이름 옆 꼬리표
	{id = "drone", n = "드론 편대", t = "DRN", max = 5, sub = true, tag = "새 드론", d = "레벨마다 다른 드론이 한 기씩 늘어납니다", dl = [
		"사격 드론: 주위를 돌며 사격합니다. 24발을 쏘면 재장전",
		"자폭 드론 추가: 9초마다 출격해 적이 뭉친 곳에 돌입합니다",
		"화염방사 드론 추가: 가까운 적을 불태웁니다",
		"전기 드론 추가: 적 여럿에게 연쇄 방전을 걸어 잠깐 멈춥니다",
		"방어 드론 추가: 날아오는 적 탄환과 포탄을 요격합니다"]},
	{id = "taser", n = "테이저 방전", t = "TSR", max = 5, sub = true, d = "가까운 적 여럿에게 전기 충격"},
	{id = "squad", n = "부대원 합류", t = "SQD", max = 4, sub = true, tag = "새 부대원", d = "레벨마다 부대원이 한 명씩 합류합니다", dl = [
		"소총수 합류: 뒤를 따르며 교전합니다. 포위되면 가장 얇은 쪽에 화력을 모아 탈출로를 엽니다",
		"지원병 합류: 경기관총으로 탄막을 깝니다",
		"공병 합류: 단말기·통신탑에 다가가면 모스 부호를 대신 넣어 줍니다",
		"의무병 합류: 곁에 있는 동안 체력이 천천히 회복됩니다"]},
]
const EVOS := [
	{id = "ar", w = "ar", n = "스마트 소총", d = "연사·화력 +30%, 탄환이 적 사이를 4번 도탄하고 처치한 적이 터집니다", need = {rate = 3, pierce = 2}},
	{id = "sg", w = "sg", n = "용의 숨결", d = "산탄 +4발에 관통 +2, 불붙은 적은 죽으면서 폭발합니다", need = {multi = 2, dmg = 3}},
	{id = "lmg", w = "lmg", n = "미니건", d = "재장전 없음, 연사 +90%, 다섯 발마다 작렬탄", need = {mag = 3, rate = 3}},
	{id = "rail", w = "rail", n = "플라즈마 레일", d = "무한 관통, 명중할 때마다 큰 폭발", need = {pierce = 2, blast = 3}},
	{id = "gren", sub = "gren", n = "집속 수류탄", d = "폭발 후 자탄 4개가 추가로 터집니다", need = {gren = 3, blast = 3}},
	{id = "drone", sub = "drone", n = "군집 드론", d = "자폭 드론이 4기씩 떼로 출격하고 사격 드론이 3기로 늘어납니다", need = {drone = 3, rate = 3}},
	{id = "comms", any = true, n = "요청 드론", d = "드론이 장착한 지원요청을 상황에 맞게 자동 호출합니다. 재사용 대기는 플레이어와 별도", need = {cd = 3, blast = 2}},
	{id = "squad", sub = "squad", n = "특수부대 분대", d = "부대원 전원이 특수부대 장비로 바뀝니다. 화력 +60%에 관통 +1, 포위 돌파가 더 거세지고 공병의 해킹이 두 배 빨라집니다", need = {squad = 3, hp = 2}},
	{id = "taser", sub = "taser", n = "폭풍 방전", d = "범위 안 모든 적을 감전시키고 잠깐 기절", need = {taser = 3, cd = 3}},
]
## vis: 시야 거리
const ET := {
	ru = {hp = 20.0, spd = 76.0, r = 9.0, dmg = 3.0, xp = 1, vis = 160.0},
	sh = {hp = 140.0, spd = 46.0, r = 13.0, dmg = 8.0, xp = 4, vis = 150.0},
	rf = {hp = 45.0, spd = 55.0, r = 10.0, dmg = 6.0, xp = 3, ranged = true, vis = 200.0},
	dr = {hp = 10.0, spd = 128.0, r = 7.0, dmg = 12.0, xp = 2, fly = true, vis = 180.0},
	tk = {hp = 900.0, spd = 32.0, r = 24.0, dmg = 24.0, xp = 0, armor = 0.4, vis = 330.0},
	## 경전차: 빠르고 얇다. 기관포를 자주 쏜다 (th: 포탑 높이 m)
	lt = {hp = 380.0, spd = 46.0, r = 20.0, dmg = 13.0, xp = 0, armor = 0.6, vis = 300.0, th = 0.9},
	## 이동식 지대지 미사일 발사대: 아주 멀리서 4발 연사. 느리고 약하다
	ml = {hp = 480.0, spd = 26.0, r = 26.0, dmg = 20.0, xp = 0, armor = 0.55, vis = 240.0, th = 1.25},
	## 길리 저격수: 땅과 같은 색 위장복을 쓰고 엎드려 있어 잘 안 보인다. 조준선을 겨눈 뒤 한 발이 아프다
	sn = {hp = 30.0, spd = 0.0, r = 9.0, dmg = 28.0, xp = 5, vis = 430.0},
	## ---- 보스 (스테이지 5 · 8 · 10의 주 임무). n: 이름, th: 주포탑 높이 ----
	b1 = {hp = 4500.0, spd = 26.0, r = 34.0, dmg = 30.0, xp = 0, armor = 0.5, vis = 420.0, th = 1.75, boss = true, n = "다포탑 중전차 「코뿔소」"},
	b2 = {hp = 7000.0, spd = 0.0, r = 50.0, dmg = 45.0, xp = 0, armor = 0.6, vis = 500.0, th = 1.7, boss = true, n = "열차포 「천둥」"},
	b3 = {hp = 9000.0, spd = 14.0, r = 62.0, dmg = 30.0, xp = 0, armor = 0.6, vis = 520.0, th = 3.1, boss = true, n = "이동 지휘 요새 「성채」"},
	## 자주포: 멀리서 곡사 (떨어질 자리 예고)
	sp = {hp = 650.0, spd = 24.0, r = 24.0, dmg = 22.0, xp = 0, armor = 0.4, vis = 260.0},
}
const BIOMES := [
	{n = "사막 시가지", g = ["#ad9070", "#a28666", "#967a5c", "#b79b7b"], road = "#4a4641", roadE = "#89775f", lane = "#cfc39e", rock = "#948570", deco = "#786b4c",
		sun = "#f5e1c4", amb = "#c1a68a", sky = "#d0b79a", fog = "#c0a486",
		kinds = [["bld", 40], ["car", 12], ["cont", 10], ["sand", 12], ["palm", 14], ["rock", 12]], roof = ["#b2a99a", "#9f9788", "#bcb4a3", "#958c7d"], wall = ["#847b6d", "#756d5f", "#8f8675", "#6b6357"]},
	{n = "산림 마을", g = ["#576244", "#4e593e", "#444f36", "#616c4d"], road = "#5a5246", roadE = "#474435", lane = "", rock = "#7e8482", deco = "#819462",
		sun = "#e6e6d9", amb = "#798473", sky = "#9eac9f", fog = "#899485",
		kinds = [["tree", 44], ["pine", 12], ["rock", 14], ["bld", 14], ["car", 8], ["sand", 8]], roof = ["#67453d", "#4c4844", "#755446", "#3e4245"], wall = ["#9c978a", "#898479", "#a9a293", "#78746b"]},
	{n = "설원 기지", g = ["#ced2d5", "#c3c9cd", "#b6bdc3", "#dadee1"], road = "#565a5f", roadE = "#99a0a6", lane = "#dfd088", rock = "#8e969f", deco = "#aab5c0", snow = true,
		sun = "#e5eaf5", amb = "#919cb1", sky = "#bac5d3", fog = "#bfc7cf",
		kinds = [["pine", 40], ["rock", 16], ["cont", 14], ["bld", 18], ["sand", 12]], roof = ["#e1e4e6", "#d9dde1", "#d1d6da"], wall = ["#5c636c", "#67544f", "#4f564b"]},
]

## 이 지원요청을 사려면 먼저 가지고 있어야 하는 것 (계열의 바로 앞 단계). 없으면 ""
static func req_of(id: String) -> String:
	for br in BRANCHES:
		var i: int = br.ids.find(id)
		if i > 0:
			return br.ids[i - 1]
	return ""


## 같은 계열의 바로 아래 등급 무기 wid. 1등급이면 ""
static func wreq_of(w: Dictionary) -> String:
	for x in WEAPONS:
		if x.id == w.id and x.tier == w.tier - 1:
			return x.wid
	return ""


static func dps(w: Dictionary) -> float:
	return w.dmg * w.pellets * w.rate


static func strat(id: String) -> Dictionary:
	for s in STRATS:
		if s.id == id:
			return s
	return {}

## wid(상점 이름)로 무기를 찾는다
static func weapon(wid: String) -> Dictionary:
	for w in WEAPONS:
		if w.wid == wid:
			return w
	return WEAPONS[0]

static func up_name(id: String) -> String:
	for u in UPS:
		if u.id == id:
			return u.n
	return id
