extends Node
## 효과음 합성기 (오토로드 "Synth"). 프로토타입의 WebAudio beep/noise/tone을 AudioStreamGenerator로 재현한다.

const RATE := 22050.0
const MAX_VOICES := 14

var enabled := true
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _voices: Array = []
var _key_on := false
var _key_ph := 0.0

## ---- 전투 음악 (효과음과 따로 도는 층). level: 0 꺼짐 / 1 긴장(증원) / 2 절정(탈출·보스) ----
## 152 BPM, 라단조, 4마디 순환(Dm – Bb – F – C). 질주하는 저음 + 끊어 치는 화음 + 북 + (절정에서) 선율
const M_STEP := 60.0 / 152.0 / 4.0
const M_ROOT := [73.42, 58.27, 87.31, 65.41]
const M_CHORD := [[293.66, 349.23, 440.0], [233.08, 293.66, 349.23], [349.23, 440.0, 523.25], [329.63, 392.0, 523.25]]
const M_BASS := [0, 3, 4, 6, 8, 11, 12, 14]
## 선율: [마디, 박(16분), 주파수, 길이(16분)]
const M_LEAD := [[0, 0, 440.0, 6], [0, 6, 587.33, 6], [0, 12, 698.46, 4], [1, 0, 698.46, 4], [1, 4, 587.33, 4], [1, 8, 466.16, 8],
	[2, 0, 523.25, 6], [2, 6, 698.46, 6], [2, 12, 880.0, 4], [3, 0, 783.99, 8], [3, 8, 659.26, 4], [3, 12, 523.25, 4]]
var _m_level := 0
var _m_clock := 0.0
var _m_next := 0.0
var _m_step := 0
var _mv: Array = []


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.08
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()


## 짧은 음. kind: square / sine / sawtooth
## delay 초 뒤에 시작 (팡파르처럼 이어지는 음)
func beep(f: float, d: float, kind := "square", v := 0.05, slide := 0.0, delay := 0.0) -> void:
	if not enabled or _voices.size() >= MAX_VOICES:
		return
	_voices.append({f = f, d = d, t = -delay, k = kind, v = v, slide = slide, ph = 0.0})


## 저역 통과 잡음 (폭발·사격)
func noise(d: float, v: float, freq: float, delay := 0.0) -> void:
	if not enabled or _voices.size() >= MAX_VOICES:
		return
	_voices.append({d = d, t = -delay, k = "noise", v = v, lp = 0.0, a = clampf(freq / RATE * TAU, 0.01, 1.0)})


## 전투 음악 세기를 바꾼다. 같은 값이면 아무 일도 없다 (매 프레임 불러도 된다)
func music(level: int) -> void:
	if level == _m_level:
		return
	if _m_level == 0:
		## 새로 시작: 마디 처음부터
		_m_step = 0
		_m_next = _m_clock + 0.05
	_m_level = level


func _m_note(f: float, d: float, kind: String, v: float, delay: float, slide := 0.0) -> void:
	if _mv.size() < 28:
		_mv.append({f = f, d = d, t = -delay, k = kind, v = v, slide = slide, ph = 0.0})


func _m_noise(d: float, v: float, freq: float, delay: float) -> void:
	if _mv.size() < 28:
		_mv.append({d = d, t = -delay, k = "noise", v = v, lp = 0.0, a = clampf(freq / RATE * TAU, 0.01, 1.0)})


## 16분음표 한 칸을 예약한다
func _m_schedule(step: int, delay: float) -> void:
	var bar := (step / 16) % 4
	var s := step % 16
	var hot := _m_level >= 2
	## 저음: 말 달리듯 끊어 치는 근음 (한 옥타브 위를 얇게 겹친다)
	if M_BASS.has(s):
		_m_note(M_ROOT[bar], 0.2, "sawtooth", 0.05, delay)
		_m_note(M_ROOT[bar] * 2.0, 0.14, "square", 0.014, delay)
	## 화음: 8분(절정에서는 16분)으로 끊어 치는 분산 화음
	if s % 2 == 0 or hot:
		var ch: Array = M_CHORD[bar]
		_m_note(ch[(s / (1 if hot else 2)) % 3], 0.13, "square", 0.016 if hot else 0.012, delay)
	## 북: 큰북(1·3박과 당김) + 작은북(2·4박) + 절정에서 잔박
	if s == 0 or s == 8 or s == 6 or (hot and s == 14):
		_m_note(95.0, 0.16, "sine", 0.09, delay, -60.0)
	if s == 4 or s == 12:
		_m_noise(0.11, 0.05, 2600.0, delay)
	if hot and s % 2 == 1:
		_m_noise(0.03, 0.018, 7000.0, delay)
	## 마디 첫 박: 낮은 금관 느낌의 5도 화음
	if s == 0:
		_m_note(M_ROOT[bar] * 2.0, 0.9, "sawtooth", 0.028, delay)
		_m_note(M_ROOT[bar] * 3.0, 0.9, "sawtooth", 0.018, delay)
	## 절정: 선율
	if hot:
		for n in M_LEAD:
			if n[0] == bar and n[1] == s:
				_m_note(n[2], M_STEP * n[3] * 1.5, "sawtooth", 0.03, delay)
				_m_note(n[2] * 0.5, M_STEP * n[3] * 1.5, "square", 0.012, delay)


## 전건을 누르고 있는 동안 나는 연속음
func tone(on: bool) -> void:
	_key_on = on and enabled


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	## 음악: 이번 버퍼 구간에 걸리는 박을 예약한다
	if enabled and _m_level > 0:
		var span := n / RATE
		while _m_next < _m_clock + span + 0.02:
			_m_schedule(_m_step, maxf(0.0, _m_next - _m_clock))
			_m_step += 1
			_m_next += M_STEP
	_m_clock += n / RATE
	var buf := PackedVector2Array()
	buf.resize(n)
	var inv := 1.0 / RATE
	for i in n:
		var s := 0.0
		for vc in _voices:
			if vc.t >= vc.d:
				continue
			if vc.t < 0.0:
				vc.t += inv
				continue
			var k: float = vc.t / vc.d
			var env: float = vc.v * (1.0 - k) * (1.0 - k)
			if vc.k == "noise":
				vc.lp += vc.a * (randf() * 2.0 - 1.0 - vc.lp)
				s += vc.lp * env * 4.0
			else:
				var f: float = maxf(30.0, vc.f + vc.slide * k)
				vc.ph = fmod(vc.ph + f * inv, 1.0)
				var ph: float = vc.ph
				if vc.k == "sine":
					s += sin(ph * TAU) * env
				elif vc.k == "sawtooth":
					s += (ph * 2.0 - 1.0) * env
				else:
					s += (1.0 if ph < 0.5 else -1.0) * env
			vc.t += inv
		for vc in _mv:
			if vc.t >= vc.d:
				continue
			if vc.t < 0.0:
				vc.t += inv
				continue
			var mk: float = vc.t / vc.d
			var menv: float = vc.v * (1.0 - mk) * minf(1.0, vc.t * 200.0)
			if vc.k == "noise":
				vc.lp += vc.a * (randf() * 2.0 - 1.0 - vc.lp)
				s += vc.lp * menv * 4.0
			else:
				var mf: float = maxf(30.0, vc.f + vc.slide * mk)
				vc.ph = fmod(vc.ph + mf * inv, 1.0)
				if vc.k == "sine":
					s += sin(vc.ph * TAU) * menv
				elif vc.k == "sawtooth":
					s += (vc.ph * 2.0 - 1.0) * menv
				else:
					s += (1.0 if vc.ph < 0.5 else -1.0) * menv
			vc.t += inv
		if _key_on:
			_key_ph = fmod(_key_ph + 660.0 * inv, 1.0)
			s += (1.0 if _key_ph < 0.5 else -1.0) * 0.05
		s = clampf(s, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	_pb.push_buffer(buf)
	_voices = _voices.filter(func(vc): return vc.t < vc.d)
	_mv = _mv.filter(func(vc): return vc.t < vc.d)
