extends Node
# Procedural sound effects + a tiny chiptune loop, synthesised at start-up (no audio files needed).

const RATE := 22050

var sounds := {}
var voices: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		voices.append(p)
	sounds["jump"] = _tone(320, 720, 0.16, "square", 0.22)
	sounds["jump2"] = _tone(480, 980, 0.16, "square", 0.22)
	sounds["land"] = _tone(140, 60, 0.09, "sine", 0.35, 0.15)
	sounds["fart"] = _fart(0.55, 1.0)
	sounds["fart2"] = _fart(0.4, 1.35)
	sounds["slide"] = _tone(260, 120, 0.3, "saw", 0.12, 0.7)
	sounds["slam"] = _tone(180, 40, 0.28, "sine", 0.55, 0.3)
	sounds["fruit"] = _tone(880, 1320, 0.1, "square", 0.16)
	sounds["crate"] = _tone(300, 90, 0.18, "saw", 0.35, 0.8)
	sounds["bounce"] = _tone(200, 520, 0.2, "sine", 0.4)
	sounds["clank"] = _tone(700, 500, 0.12, "square", 0.2, 0.3)
	sounds["life"] = _arp([523, 659, 784, 1047, 1319], 0.09, "square", 0.2)
	sounds["checkpoint"] = _arp([392, 523, 659], 0.09, "square", 0.2)
	sounds["mask"] = _arp([330, 440, 554, 660], 0.07, "sine", 0.3)
	sounds["fuse"] = _tone(900, 900, 0.07, "square", 0.12)
	sounds["boom"] = _tone(120, 30, 0.7, "saw", 0.7, 0.85)
	sounds["enemy"] = _tone(400, 80, 0.2, "square", 0.25, 0.2)
	sounds["hurt"] = _tone(600, 100, 0.45, "saw", 0.3, 0.2)
	sounds["die"] = _arp([523, 440, 349, 262, 196], 0.12, "square", 0.25)
	sounds["win"] = _arp([523, 659, 784, 1047, 784, 1047, 1319], 0.11, "square", 0.22)
	sounds["rumble"] = _tone(60, 50, 0.5, "saw", 0.3, 0.6)
	_start_music()


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not sounds.has(name):
		return
	var p := voices[_next]
	_next = (_next + 1) % voices.size()
	p.stream = sounds[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _wave(kind: String, phase: float) -> float:
	var ph := fposmod(phase, 1.0)
	match kind:
		"sine":
			return sin(TAU * ph)
		"square":
			return 1.0 if ph < 0.5 else -1.0
		"tri":
			return absf(ph * 4.0 - 2.0) - 1.0
		_:
			return ph * 2.0 - 1.0


func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tone(f0: float, f1: float, dur: float, kind: String, vol: float, noise := 0.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var s := lerpf(_wave(kind, phase), randf() * 2.0 - 1.0, noise)
		var env := (1.0 - t) * minf(1.0, t * 60.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	return _make_stream(data)


# Cartoon fart: a low buzzing tone with a fast flutter, a drifting pitch and a bit of noise.
func _fart(dur: float, pitch: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var flutter_phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := (105.0 + 55.0 * sin(t * 9.0) - 40.0 * t) * pitch
		phase += f / RATE
		flutter_phase += lerpf(46.0, 24.0, t) / RATE
		var flutter := pow(maxf(0.0, sin(TAU * flutter_phase)), 0.6)
		var tone := _wave("saw", phase) * 0.7 + _wave("square", phase * 0.5) * 0.3
		var s := lerpf(tone, randf() * 2.0 - 1.0, 0.22) * (0.35 + 0.65 * flutter)
		var env := minf(1.0, t * 25.0) * (1.0 - pow(t, 3.0))
		data.encode_s16(i * 2, int(clampf(s * env * 0.6, -1.0, 1.0) * 32767.0))
	return _make_stream(data)


func _arp(freqs: Array, step: float, kind: String, vol: float) -> AudioStreamWAV:
	var per := int(RATE * step)
	var n: int = per * freqs.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var idx: int = i / per
		var t := float(i % per) / per
		phase += float(freqs[idx]) / RATE
		var env := (1.0 - t * 0.7) * minf(1.0, t * 80.0)
		if idx == freqs.size() - 1:
			env *= 1.0 - float(i % per) / per * 0.3
		data.encode_s16(i * 2, int(clampf(_wave(kind, phase) * env * vol, -1.0, 1.0) * 32767.0))
	return _make_stream(data)


# A bouncy 8-bar loop: bass + lead, C major.
func _start_music() -> void:
	var bpm := 150.0
	var step := 60.0 / bpm / 2.0           # eighth notes
	var per := int(RATE * step)
	var lead := [
		523, 0, 659, 0, 784, 659, 523, 0,   587, 0, 698, 0, 880, 698, 587, 0,
		659, 0, 784, 0, 988, 784, 659, 0,   523, 659, 784, 659, 523, 392, 523, 0,
	]
	var bass := [
		131, 131, 196, 131, 131, 131, 196, 131,   147, 147, 220, 147, 147, 147, 220, 147,
		165, 165, 247, 165, 165, 165, 247, 165,   131, 131, 196, 131, 196, 131, 98, 131,
	]
	var n := per * lead.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	var pl := 0.0
	var pb := 0.0
	for i in n:
		var idx: int = i / per
		var t := float(i % per) / per
		var s := 0.0
		if lead[idx] > 0:
			pl += float(lead[idx]) / RATE
			s += _wave("square", pl) * 0.5 * (1.0 - t * 0.6)
		pb += float(bass[idx]) / RATE
		s += _wave("tri", pb) * 0.9 * (1.0 - t * 0.25)
		data.encode_s16(i * 2, int(clampf(s * 0.13, -1.0, 1.0) * 32767.0))
	var w := _make_stream(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	music_player = AudioStreamPlayer.new()
	music_player.stream = w
	music_player.volume_db = -6.0
	add_child(music_player)
	music_player.play()


func set_music(on: bool) -> void:
	if music_player:
		music_player.stream_paused = not on
