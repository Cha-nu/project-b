# ProjectB (모스 스트라이크, Godot 4.7)

모스 부호로 지원요청을 부르는 2.5D 쿼터뷰 은신 슈터. HTML 프로토타입(MorseStrike `index.html`)을 Godot로 옮긴 프로젝트이고, 이제 이쪽이 본편이다. 구조·좌표·규칙 요약은 `README.md`에 있다. 이 PC의 실제 경로(프로토타입, Godot 실행 파일, 블로그 저장소)는 git에 올리지 않는 `CLAUDE.local.md`에 있다.

## 실행과 확인

Godot 4.7.2 에디터 실행 파일을 `godot`로 쓴다.

```bash
# 스크립트 로드 오류만 빠르게
godot --headless --path . --quit-after 120
# 창을 띄워 자동 점검 (로비 → 출격 → 지원요청 → 입력 → 진화 → 증원 → 1분 시뮬레이션 → 탐색 실험)
godot --path . -- --autotest
```

- 자동 점검은 `AUTOTEST ...` 줄을 출력하고 `%APPDATA%\Godot\app_userdata\ProjectB\autotest_*.png` 스크린샷을 남긴다. 바꾼 뒤에는 오류(`SCRIPT ERROR`)가 없는지와 관련 스크린샷을 직접 열어 본다.
- 저장 파일의 투하 위치가 "수동"이면 `AUTOTEST key ... fired=false`, `joystick dx=0`이 나온다. 공습이 수동 조준 대기로 들어간 것이라 버그가 아니다.
- 레벨업 창이 뜨면 `game.pause == "lvl"`이라 `later()` 타이머가 멈춘다. 시간 대기형 테스트 전에는 닫는다.

## GDScript 주의

- 지역 변수 `:=`는 Dictionary 값에서 타입을 추론하지 못해 오류가 난다. `var x = ...`를 쓴다.
- 개체(적·총알 등)가 Dictionary라 `==`는 깊은 비교다. 같은 개체인지는 `is_same()`이나 `uid`로 본다.
- Dictionary에 키가 빠지면 실행 중에야 터진다. 새 필드는 `spawn()` 같은 생성 지점에 기본값을 넣는다. (증원 적에 `px`가 없어 오류 났던 적이 있다)
- 오토로드 `Synth`, `Save`는 `--check-only`에서 "Identifier not found"로 보이지만 정상이다.
- `game.gd`가 3000줄짜리 한 파일이다(프로토타입 `update()` 구조를 그대로 옮김). 리팩터링 제안: 적 Dictionary → `class_name Enemy`부터, 이후 MorseInput / EnemyDirector / StrikeSystem / OverlayRenderer 분리. 사용자가 원하면 단계별로, 매번 자동 점검으로 확인하며 진행한다.

## 사용자가 정한 방향 (바꾸지 말 것)

- 2.5D 쿼터뷰(헬다이버즈 1 같은 현대 배경), 플레이어는 특수부대 디자인
- 게임 안 용어는 "지원요청". "스트라타젬" 금지 (코드 식별자 `STRATS`는 그대로)
- 무한 스폰 없음. 경비병·순찰조가 발견하면 무전병이 증원을 부른다. 무전병을 죽이면 증원 취소 + 플레이어 지원요청 대기 30%(최소 3초) 단축
- 증원은 크게 몰려온다(22 + 증원 횟수 x 8, 최대 60, 3파). 통신탑 점령 중에는 은신과 무관하게 증원이 오고, 점령 게이지는 줄지 않는다
- 자동 조준은 기본 기능(가장 가까운 적, 엄폐물에 가린 적은 건너뜀). 플레이어는 이동 방향을 바라본다
- 무기 진화는 카타르시스 있게(슬로모션·줌인·충격파). 통신 드론 진화는 지원요청을 자동 호출하고 대기는 플레이어와 별도
- 폭격류는 실제 폭발 반경을 지점마다 표시하고, 전투기가 지나가며 그림자와 소리를 낸다
- UI는 상용 모바일 게임 톤(둥근 카드, 입체 버튼, 남색+금색). 미션은 가상 세계 지구본(`scripts/globe.gd`)에서 고른다

## 블로그

개발일지는 블로그 저장소(`Cha-nu.github.io`, Astro)에 `project: project-b`로 올린다. 그 저장소의 `AGENTS.md` 규칙을 따른다: 새 글은 `draft: true`, 수치는 `research/`에서 다시 낼 수 있어야 함, push는 사용자가 요청할 때만. 첫 글: `src/content/posts/project-b-2026-11-10-auto-aim-grid-search.md`, 측정 코드 `research/project-b-nearest/`. `src/content/projects/project-b.md`(프로젝트 소개 페이지)는 아직 없다.
