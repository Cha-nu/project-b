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


## 전건을 누르고 있는 동안 나는 연속음
func tone(on: bool) -> void:
	_key_on = on and enabled


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
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
		if _key_on:
			_key_ph = fmod(_key_ph + 660.0 * inv, 1.0)
			s += (1.0 if _key_ph < 0.5 else -1.0) * 0.05
		s = clampf(s, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	_pb.push_buffer(buf)
	_voices = _voices.filter(func(vc): return vc.t < vc.d)
