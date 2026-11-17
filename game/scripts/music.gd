extends RefCounted
# The background music: an old-school rock guitar riff, synthesised.
#   guitar : a plucked string (Karplus-Strong) pushed through overdrive; power chords, palm-muted chugs, a lead lick
#   bass   : plucked triangle, eighth notes following the chords      drums : kick, snare and hi-hats
# 16 bars in E minor at 132 bpm (about 29 s), looping seamlessly (note tails wrap around the end).

const RATE := 32000        # high enough that the plucked strings can be tuned finely (whole-sample delay lines)
const BPM := 132.0
const STEPS := 16
const BARS := 16

# note = [step, name, length in steps, kind]  kind: "P" open power chord, "m" palm-muted chug, "s" single lead note
const A1 := [[0, "E2", 3, "P"], [3, "E2", 1, "m"], [4, "E2", 2, "P"], [6, "G2", 1, "m"], [7, "A2", 3, "P"], [10, "G2", 1, "m"], [11, "E2", 1, "m"], [12, "D2", 2, "P"], [14, "E2", 2, "P"]]
const A2 := [[0, "E2", 3, "P"], [3, "E2", 1, "m"], [4, "E2", 2, "P"], [6, "G2", 1, "m"], [7, "A2", 3, "P"], [10, "B2", 2, "P"], [12, "A2", 1, "m"], [13, "G2", 1, "m"], [14, "E2", 2, "P"]]
const B1 := [[0, "A2", 3, "P"], [3, "A2", 1, "m"], [4, "A2", 2, "P"], [6, "B2", 1, "m"], [7, "D3", 3, "P"], [10, "B2", 1, "m"], [11, "A2", 1, "m"], [12, "G2", 2, "P"], [14, "E2", 2, "P"]]
const B2 := [[0, "E3", 2, "s"], [2, "G3", 1, "s"], [3, "A3", 2, "s"], [5, "B3", 1, "s"], [6, "A3", 1, "s"], [7, "G3", 2, "s"], [9, "E3", 3, "s"], [12, "D3", 1, "s"], [13, "E3", 3, "s"]]
const C1 := [[0, "E2", 2, "P"], [2, "E2", 1, "m"], [3, "E2", 1, "m"], [4, "E2", 1, "m"], [6, "E2", 1, "m"], [8, "E2", 2, "P"], [10, "E2", 1, "m"], [12, "E2", 1, "m"], [14, "E2", 1, "m"], [15, "G2", 1, "m"]]
const C2 := [[0, "E2", 2, "P"], [2, "E2", 1, "m"], [3, "E2", 1, "m"], [4, "G2", 2, "P"], [6, "G2", 1, "m"], [8, "A2", 2, "P"], [10, "A2", 1, "m"], [11, "B2", 1, "m"], [12, "D3", 3, "P"]]
const C3 := [[0, "B3", 2, "s"], [2, "A3", 1, "s"], [3, "G3", 1, "s"], [4, "E3", 3, "s"], [8, "G3", 1, "s"], [9, "A3", 1, "s"], [10, "B3", 2, "s"], [12, "D4", 2, "s"], [14, "B3", 2, "s"]]
# which riff each bar plays, and the bass root for each of its four beats
const SONG := [
	[A1, ["E2", "G2", "A2", "D2"]], [A2, ["E2", "G2", "A2", "B2"]], [A1, ["E2", "G2", "A2", "D2"]], [A2, ["E2", "G2", "A2", "B2"]],
	[B1, ["A2", "A2", "D3", "G2"]], [B1, ["A2", "A2", "D3", "G2"]], [B2, ["E2", "E2", "E2", "E2"]], [A2, ["E2", "G2", "A2", "B2"]],
	[C1, ["E2", "E2", "E2", "E2"]], [C1, ["E2", "E2", "E2", "E2"]], [C2, ["E2", "G2", "A2", "D3"]], [C2, ["E2", "G2", "A2", "D3"]],
	[C1, ["E2", "E2", "E2", "E2"]], [C2, ["E2", "G2", "A2", "D3"]], [C3, ["E2", "E2", "E2", "E2"]], [A2, ["E2", "G2", "A2", "B2"]],
]


static func freq(note: String) -> float:
	var semis := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var midi: int = 12 * (int(note.substr(note.length() - 1)) + 1) + int(semis[note.substr(0, 1)])
	if note.length() == 3:
		midi += 1 if note[1] == "#" else -1
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


# A plucked string: a burst of noise circulating in a delay line that is slightly low-passed each pass.
# The delay is fractional (a blend of two neighbouring lengths) so every note is tuned exactly.
static func _string(f: float, dur: float, decay: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var p := RATE / f - 0.5                    # the averaging filter itself adds half a sample of delay
	var l := int(floor(p))
	var a := p - l
	var m := l + 3
	var buf := PackedFloat32Array()
	buf.resize(m)
	for i in m:
		buf[i] = rng.randf() * 2.0 - 1.0
	var out := PackedFloat32Array()
	out.resize(n)
	var w := 0                                  # next write position; the newest sample is at w-1
	for i in n:
		var i0 := w - l
		if i0 < 0:
			i0 += m
		var i1 := i0 - 1
		if i1 < 0:
			i1 += m
		var i2 := i1 - 1
		if i2 < 0:
			i2 += m
		var x0 := buf[i0]
		var x1 := buf[i1]
		var x2 := buf[i2]
		var y := decay * ((1.0 - a) * 0.5 * (x0 + x1) + a * 0.5 * (x1 + x2))
		buf[w] = y
		out[i] = y
		w += 1
		if w >= m:
			w = 0
	return out


# An overdriven guitar note: power chords are root + fifth + octave, all pushed through the same clipper.
static func _guitar(note: String, kind: String, steps_len: int, step_dur: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var f := freq(note)
	var muted := kind == "m"
	var dur := steps_len * step_dur + (0.05 if muted else 0.32)
	var decay := 0.972 if muted else 0.9985
	var drive := 4.5 if muted else 6.5
	var voices := [[f, 1.0]]
	if kind == "P":
		voices = [[f, 1.0], [f * 1.4983, 1.0], [f * 2.0, 0.9]]
	elif kind == "m":
		voices = [[f, 1.0], [f * 1.4983, 0.6]]
	var n := int(RATE * dur)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for v in voices:
		var s := _string(v[0], dur, decay, rng)
		var w: float = v[1]
		for i in n:
			mix[i] += s[i] * w
	var lp := 0.0
	var low := 0.0
	var fade := int(0.03 * RATE)
	for i in n:
		# like an overdrive pedal: cut the mud below ~200 Hz BEFORE clipping, so the crunch is in the upper harmonics
		low += (mix[i] - low) * 0.04
		var y := tanh((mix[i] - low * 0.85) * drive * 0.55)
		lp += (y - lp) * 0.5                        # take the fizz off the top
		var e := 1.0
		if i > n - fade:
			e = float(n - i) / fade
		mix[i] = lp * e
	return mix


static func _kick() -> PackedFloat32Array:
	var n := int(0.2 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += (45.0 + 110.0 * exp(-t * 28.0)) / RATE
		out[i] = sin(TAU * ph) * exp(-t * 15.0)
	return out


static func _snare(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.18 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var nz := rng.randf() * 2.0 - 1.0
		var hp := nz - prev * 0.6                  # brighter noise
		prev = nz
		out[i] = hp * exp(-t * 24.0) * 0.8 + sin(TAU * 185.0 * t) * exp(-t * 40.0) * 0.5
	return out


static func _hat(open: bool, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int((0.22 if open else 0.05) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var nz := rng.randf() * 2.0 - 1.0
		out[i] = (nz - prev) * exp(-t * (14.0 if open else 85.0))
		prev = nz
	return out


static func _bass(note: String, steps_len: int, step_dur: float) -> PackedFloat32Array:
	var f := freq(note)
	var n := int((steps_len * step_dur + 0.04) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var ph := fposmod(t * f, 1.0)
		var tri := absf(ph * 4.0 - 2.0) - 1.0
		var e := exp(-t * 7.0) * 0.7 + 0.3
		if i > n - 240:
			e *= float(n - i) / 240.0
		out[i] = (tri * 0.8 + sin(TAU * t * f * 2.0) * 0.25) * e
	return out


static func _add(mix: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float) -> void:
	var total := mix.size()
	var m := src.size()
	var j := at
	for i in m:
		if j >= total:
			j -= total                              # wrap around: the loop is seamless
		mix[j] += src[i] * gain
		j += 1


static func build() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var step_dur := 60.0 / BPM / 4.0
	var bar_len := int(round(STEPS * step_dur * RATE))
	var total := bar_len * BARS
	var mix := PackedFloat32Array()
	mix.resize(total)
	var cache := {}
	var kick := _kick()
	var snare := _snare(rng)
	var hat := _hat(false, rng)
	var open_hat := _hat(true, rng)
	for b in BARS:
		var base := b * bar_len
		var riff: Array = SONG[b][0]
		var roots: Array = SONG[b][1]
		# guitar
		for nt in riff:
			var key := "%s_%s_%d" % [nt[1], nt[3], nt[2]]
			if not cache.has(key):
				cache[key] = _guitar(nt[1], nt[3], nt[2], step_dur, rng)
			var gain := 0.62 if nt[3] == "s" else 0.55
			_add(mix, cache[key], base + int(nt[0] * step_dur * RATE), gain)
		# bass: eighth notes on the chord root of each beat
		for e in 8:
			var bn: String = roots[e / 2]
			var bkey := "bass_%s" % bn
			if not cache.has(bkey):
				cache[bkey] = _bass(bn, 2, step_dur)
			_add(mix, cache[bkey], base + int(e * 2 * step_dur * RATE), 0.26)
		# drums
		for s in [0, 8, 10]:
			_add(mix, kick, base + int(s * step_dur * RATE), 0.7)
		for s in [4, 12]:
			_add(mix, snare, base + int(s * step_dur * RATE), 0.42)
		for s in range(0, 16, 2):
			_add(mix, open_hat if s == 14 and b % 2 == 1 else hat, base + int(s * step_dur * RATE), 0.12)
		if b % 4 == 3:                                  # a snare roll at the end of every phrase
			for s in [13, 14, 15]:
				_add(mix, snare, base + int(s * step_dur * RATE), 0.3)
	# normalise and convert to 16-bit
	var peak := 0.0001
	for i in total:
		peak = maxf(peak, absf(mix[i]))
	var data := PackedByteArray()
	data.resize(total * 2)
	var k := 0.86 / peak
	for i in total:
		data.encode_s16(i * 2, int(clampf(mix[i] * k, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	return w
