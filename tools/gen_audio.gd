extends SceneTree
## Sintetiza os efeitos sonoros e a trilha do Monstel e grava WAV 16-bit mono em res://assets/audio/.
## Uso: tools\dev.bat script res://tools/gen_audio.gd
## Ao final imprime o controle de qualidade numérico (pico, RMS, clipping, DC, cliques nas pontas).

const SR := 22050
const OUT := "res://assets/audio/"

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 20261107
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_make_sfx()
	_make_music()
	quit(0)

# --- bloco de construção ---------------------------------------------------------------

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * float(SR)))
	return b

## Soma um tom no buffer. kind: sine | soft | bell | tri | pluck. dec = decaimento exponencial (1/s).
func _tone(b: PackedFloat32Array, t0: float, dur: float, f: float, amp: float, kind: String = "sine", atk: float = 0.006, dec: float = 6.0, wrap: bool = false, sweep_to: float = 0.0, trem: float = 0.0) -> void:
	var i0 := int(t0 * float(SR))
	var n := int(dur * float(SR))
	var phase := 0.0
	for k in range(n):
		var i := i0 + k
		if i >= b.size():
			if not wrap:
				break
			i %= b.size()
		var t := float(k) / float(SR)
		var freq := f if sweep_to <= 0.0 else lerpf(f, sweep_to, t / dur)
		phase += TAU * freq / float(SR)
		var env := minf(1.0, t / atk) * exp(-dec * t) * minf(1.0, (dur - t) / 0.03)
		var s := 0.0
		match kind:
			"soft":
				s = sin(phase) + 0.28 * sin(phase * 2.0) + 0.1 * sin(phase * 3.0)
			"bell":
				s = sin(phase) + 0.5 * sin(phase * 2.76) * exp(-3.0 * t) + 0.22 * sin(phase * 5.4) * exp(-7.0 * t)
			"tri":
				s = asin(sin(phase)) * 0.6366
			"pluck":
				s = asin(sin(phase)) * 0.6366 + 0.25 * sin(phase * 2.0) * exp(-4.0 * t)
			_:
				s = sin(phase)
		if trem > 0.0:
			s *= 0.75 + 0.25 * sin(TAU * trem * t)
		b[i] += s * env * amp

func _noise(b: PackedFloat32Array, t0: float, dur: float, amp: float, dec: float, lp: float = 0.2) -> void:
	var i0 := int(t0 * float(SR))
	var n := int(dur * float(SR))
	var y := 0.0
	for k in range(n):
		var i := i0 + k
		if i >= b.size():
			break
		var t := float(k) / float(SR)
		y += (_rng.randf_range(-1.0, 1.0) - y) * lp
		b[i] += y * amp * exp(-dec * t) * minf(1.0, t / 0.002)

func _lowpass(b: PackedFloat32Array, a: float) -> void:
	var y := 0.0
	for i in range(b.size()):
		y += (b[i] - y) * a
		b[i] = y

func _save(name: String, b: PackedFloat32Array, peak: float) -> void:
	var mx := 0.0001
	for v in b:
		mx = maxf(mx, absf(v))
	var g := peak / mx
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	var near := 0
	var sum := 0.0
	var sq := 0.0
	for i in range(b.size()):
		var v := clampf(b[i] * g, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
		if absf(v) > 0.98:
			near += 1
		sum += v
		sq += v * v
	var f := FileAccess.open(OUT + name + ".wav", FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(SR)
	f.store_32(SR * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	var n := float(maxi(1, b.size()))
	print("%-10s %5.2fs peak=%.2f rms=%.3f clip=%d dc=%+.4f ponta0=%.3f pontaN=%.3f" % [name, n / float(SR), mx * g, sqrt(sq / n), near, sum / n, absf(b[0] * g), absf(b[b.size() - 1] * g)])

# --- efeitos sonoros -------------------------------------------------------------------------

func _make_sfx() -> void:
	var b := _buf(0.42)
	_tone(b, 0.0, 0.4, 1318.5, 0.6, "bell", 0.003, 9.0)
	_tone(b, 0.07, 0.34, 1975.5, 0.4, "bell", 0.003, 10.0)
	_save("coin", b, 0.7)
	b = _buf(0.7)
	for i in range(4):
		_tone(b, float(i) * 0.065, 0.5, [1046.5, 1318.5, 1568.0, 2093.0][i], 0.5, "bell", 0.003, 6.5)
	_save("coin_big", b, 0.7)
	b = _buf(0.7)
	_tone(b, 0.0, 0.3, 120.0, 0.9, "sine", 0.002, 14.0, false, 48.0)
	_noise(b, 0.0, 0.18, 0.5, 22.0, 0.12)
	_tone(b, 0.12, 0.5, 1046.5, 0.3, "bell", 0.003, 6.0)
	_tone(b, 0.2, 0.45, 1568.0, 0.25, "bell", 0.003, 6.5)
	_save("build", b, 0.8)
	b = _buf(0.9)
	for i in range(4):
		_tone(b, float(i) * 0.09, 0.6, [523.3, 659.3, 784.0, 1046.5][i], 0.45, "soft", 0.004, 5.0)
	_tone(b, 0.38, 0.5, 1318.5, 0.25, "bell", 0.003, 6.0)
	_save("upgrade", b, 0.75)
	b = _buf(0.8)
	_tone(b, 0.0, 0.75, 880.0, 0.6, "bell", 0.003, 4.5)
	_tone(b, 0.0, 0.6, 1760.0, 0.1, "sine", 0.003, 6.0)
	_save("ding", b, 0.45)
	b = _buf(0.07)
	_tone(b, 0.0, 0.06, 1500.0, 0.6, "sine", 0.001, 60.0)
	_tone(b, 0.0, 0.06, 750.0, 0.4, "sine", 0.001, 60.0)
	_save("click", b, 0.5)
	b = _buf(0.2)
	_tone(b, 0.0, 0.18, 280.0, 0.6, "sine", 0.01, 9.0, false, 720.0)
	_noise(b, 0.0, 0.15, 0.08, 10.0, 0.4)
	_save("open", b, 0.45)
	b = _buf(0.18)
	_tone(b, 0.0, 0.16, 720.0, 0.6, "sine", 0.005, 11.0, false, 260.0)
	_save("close", b, 0.4)
	b = _buf(1.4)
	for i in range(4):
		_tone(b, float(i) * 0.11, 0.7, [523.3, 659.3, 784.0, 1046.5][i], 0.4, "soft", 0.005, 4.0)
	for fr in [1046.5, 1318.5, 1568.0]:
		_tone(b, 0.5, 0.85, fr, 0.28, "bell", 0.004, 3.2)
	_save("levelup", b, 0.8)
	b = _buf(0.9)
	for i in range(3):
		_tone(b, float(i) * 0.1, 0.6, [784.0, 1046.5, 1318.5][i], 0.5, "bell", 0.003, 5.0)
	_tone(b, 0.3, 0.55, 1568.0, 0.3, "bell", 0.003, 5.5)
	_save("goal", b, 0.75)
	b = _buf(1.5)
	for i in range(4):
		_tone(b, float(i) * 0.15, 0.8, [392.0, 523.3, 659.3, 784.0][i], 0.42, "tri", 0.01, 3.2)
	for fr in [523.3, 659.3, 784.0, 1046.5]:
		_tone(b, 0.62, 0.85, fr, 0.22, "soft", 0.01, 2.6)
	_save("vip", b, 0.7)
	b = _buf(0.5)
	_tone(b, 0.0, 0.45, 420.0, 0.7, "soft", 0.01, 4.0, false, 190.0, 6.0)
	_save("bad", b, 0.6)
	b = _buf(0.5)
	for i in range(4):
		_tone(b, float(i) * 0.05, 0.3, [1318.5, 1568.0, 1975.5, 2637.0][i], 0.4, "bell", 0.002, 9.0)
	_save("star", b, 0.55)
	b = _buf(0.9)
	_tone(b, 0.0, 0.7, 180.0, 0.5, "soft", 0.02, 1.5, false, 900.0, 12.0)
	for fr in [392.0, 523.3, 659.3]:
		_tone(b, 0.45, 0.4, fr, 0.25, "soft", 0.01, 4.0)
	_save("rush", b, 0.7)
	b = _buf(0.9)
	_tone(b, 0.0, 0.8, 540.0, 0.55, "soft", 0.04, 2.8, false, 360.0, 7.0)
	_tone(b, 0.0, 0.8, 1080.0, 0.1, "sine", 0.04, 3.5, false, 720.0, 7.0)
	_save("boo", b, 0.6)

# --- trilha ------------------------------------------------------------------------------------

func _make_music() -> void:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 16
	var total := bar * float(bars)
	var b := _buf(total)
	# acordes: [baixo, notas do pad, notas do arpejo]
	var chords := [
		[110.0, [220.0, 261.6, 329.6], [440.0, 523.3, 659.3]],      # Am
		[87.3, [174.6, 220.0, 261.6], [349.2, 440.0, 523.3]],       # F
		[130.8, [261.6, 329.6, 392.0], [523.3, 659.3, 784.0]],      # C
		[98.0, [196.0, 246.9, 293.7], [392.0, 493.9, 587.3]],       # G
	]
	var penta := [440.0, 523.3, 587.3, 659.3, 784.0, 880.0]
	for c in range(8):                                  # 8 acordes de 2 compassos
		var ch: Array = chords[c % 4]
		var t0 := float(c) * 2.0 * bar
		for fr in ch[1]:                                # pad longo, com cauda que dá a volta
			_tone(b, t0, bar * 2.0 + 1.0, fr, 0.055, "soft", 0.9, 0.35, true)
		for q in range(8):                              # baixo nos tempos 1 e 3
			_tone(b, t0 + float(q) * beat * 2.0, beat * 1.7, ch[0], 0.16, "sine", 0.012, 2.6, true)
		var arp: Array = ch[2]
		for e in range(16):                             # arpejo em colcheias
			var idx: int = [0, 1, 2, 1, 0, 1, 2, 1][e % 8]
			_tone(b, t0 + float(e) * beat * 0.5, beat * 1.4, arp[idx], 0.085, "pluck", 0.004, 4.5, true)
		for e in range(16):                             # melodia esparsa tipo glockenspiel
			if _rng.randf() < 0.28:
				_tone(b, t0 + float(e) * beat * 0.5 + beat * 0.25, beat * 2.0, penta[_rng.randi() % penta.size()], 0.075, "bell", 0.004, 3.2, true)
	_lowpass(b, 0.42)
	_save("music", b, 0.5)
