extends SceneTree
## One-shot procedural audio generator: synthesizes the game's SFX and a seamless ambient music loop
## as 16-bit mono WAV files into assets/audio/. No external assets or ffmpeg needed — Godot imports
## .wav natively. Re-run to regenerate after tweaking:
##   godot --headless --path . -s res://tools/generate_audio.gd
##
## Design: short, soft, "friendly delivery game" palette — sine/triangle tones with quick envelopes,
## filtered noise for the dice, gentle arpeggios for success. The ambient loop uses only partials whose
## frequencies are integer cycles over its duration, so it loops without a click.

const RATE := 44100
const OUT := "res://assets/audio/"
const TAU_F := 6.2831853


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save("ui_click", _ui_click())
	_save("dice", _dice())
	_save("place", _place())
	_save("reserve", _reserve())
	_save("pickup", _pickup())
	_save("deliver", _deliver())
	_save("event", _event())
	_save("power", _power())
	_save("victory", _victory())
	_save("ambient", _ambient())
	print("audio generated in ", OUT)
	quit(0)


# --- Sound designs ----------------------------------------------------------

func _ui_click() -> PackedFloat32Array:
	return _tone(820.0, 0.05, 0.35, "perc")


func _dice() -> PackedFloat32Array:
	# Three quick noise "clacks" decaying — a tumble.
	var out := PackedFloat32Array()
	for i in 3:
		out.append_array(_silence(0.04 if i > 0 else 0.0))
		out.append_array(_scale(_noise(0.06, "perc"), 0.5 - i * 0.12))
	return out


func _place() -> PackedFloat32Array:
	# A soft low thud: a quick low sine plus a noise click.
	var thud := _tone(140.0, 0.16, 0.5, "perc")
	var click := _scale(_noise(0.04, "perc"), 0.25)
	return _mix(thud, click)


func _reserve() -> PackedFloat32Array:
	# Two ascending blips — "noted".
	return _join([_tone(523.0, 0.09, 0.3, "perc"), _tone(784.0, 0.11, 0.3, "perc")])


func _pickup() -> PackedFloat32Array:
	# A bright ding with a harmonic.
	var a := _tone(880.0, 0.22, 0.32, "bell")
	var b := _scale(_tone(1320.0, 0.22, 0.18, "bell"), 1.0)
	return _mix(a, b)


func _deliver() -> PackedFloat32Array:
	# A happy major arpeggio C-E-G-C, bell-like — the reward.
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var out := PackedFloat32Array()
	for f in notes:
		out.append_array(_tone(f, 0.13, 0.32, "bell"))
	out.append_array(_scale(_tone(1046.5, 0.3, 0.28, "bell"), 1.0))
	return out


func _event() -> PackedFloat32Array:
	# A rising shimmer — mystery / "something happens".
	var out := PackedFloat32Array()
	var base := [659.0, 880.0, 1175.0, 1568.0]
	for f in base:
		out.append_array(_tone(f, 0.08, 0.26, "perc"))
	out.append_array(_scale(_tone(1976.0, 0.18, 0.2, "bell"), 1.0))
	return out


func _power() -> PackedFloat32Array:
	# A quick upward sweep + a bright tone — "zap".
	var sweep := _sweep(300.0, 1200.0, 0.18, 0.3)
	var ping := _tone(1568.0, 0.14, 0.25, "bell")
	return _join([sweep, ping])


func _victory() -> PackedFloat32Array:
	# A short fanfare: arpeggio then a held major chord.
	var out := PackedFloat32Array()
	for f in [523.25, 659.25, 783.99, 1046.5]:
		out.append_array(_tone(f, 0.12, 0.34, "perc"))
	var chord := _mix(_mix(_tone(523.25, 0.8, 0.22, "pad"), _tone(659.25, 0.8, 0.2, "pad")), _tone(783.99, 0.8, 0.2, "pad"))
	out.append_array(chord)
	return out


func _ambient() -> PackedFloat32Array:
	# A soft, slow pad that loops seamlessly: each partial is an integer number of cycles over DURATION,
	# and a slow amplitude LFO (also integer cycles) gives gentle motion. Low volume; mixed under SFX.
	var dur := 12.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# A warm minor-ish chord (A2, E3, A3, C4) snapped to integer cycles over the loop.
	var partials: Array[float] = [110.0, 164.81, 220.0, 261.63]
	var amps: Array[float] = [0.16, 0.12, 0.10, 0.07]
	var freqs: Array[float] = []
	for f in partials:
		freqs.append(roundf(f * dur) / dur)  # snap to whole cycles -> seamless
	var lfo := 2.0 / dur  # ~2 cycles over the loop
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in partials.size():
			s += amps[k] * sin(TAU_F * freqs[k] * t)
		var env := 0.75 + 0.25 * sin(TAU_F * lfo * t)
		out[i] = s * env * 0.6
	return out


# --- Synthesis helpers ------------------------------------------------------

# A single tone of [param freq] Hz for [param dur] s at peak [param amp], with an envelope:
# "perc" (fast attack, exp decay), "bell" (very fast attack, long decay), "pad" (slow in/out).
func _tone(freq: float, dur: float, amp: float, shape: String) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var p := float(i) / maxi(1, n - 1)
		var wave := sin(TAU_F * freq * t)
		if shape == "bell":
			wave = sin(TAU_F * freq * t) + 0.4 * sin(TAU_F * freq * 2.0 * t)
		out[i] = wave * amp * _env(p, shape)
	return out


func _env(p: float, shape: String) -> float:
	match shape:
		"pad":
			return sin(PI * p)  # smooth in and out
		"bell":
			return exp(-5.0 * p)
		_:  # perc
			var attack := minf(p / 0.02, 1.0)
			return attack * exp(-7.0 * p)


# A linear frequency sweep from [param f0] to [param f1].
func _sweep(f0: float, f1: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var p := float(i) / maxi(1, n - 1)
		var f := lerpf(f0, f1, p)
		phase += TAU_F * f / RATE
		out[i] = sin(phase) * amp * (1.0 - p * 0.3)
	return out


# White noise shaped by a percussive envelope.
func _noise(dur: float, shape: String) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in n:
		var p := float(i) / maxi(1, n - 1)
		out[i] = rng.randf_range(-1.0, 1.0) * _env(p, shape)
	return out


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func _scale(buf: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(buf.size())
	for i in buf.size():
		out[i] = buf[i] * k
	return out


# Overlays two buffers (sum), length = the longer of the two.
func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var s := 0.0
		if i < a.size():
			s += a[i]
		if i < b.size():
			s += b[i]
		out[i] = s
	return out


func _join(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


# --- WAV writing ------------------------------------------------------------

func _save(name: String, samples: PackedFloat32Array) -> void:
	var bytes := _wav_bytes(samples)
	var path := ProjectSettings.globalize_path(OUT + name + ".wav")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_buffer(bytes)
	f.close()


func _wav_bytes(samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	for s in samples:
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	_append_u32(out, 36 + data.size())
	out.append_array("WAVE".to_ascii_buffer())
	out.append_array("fmt ".to_ascii_buffer())
	_append_u32(out, 16)          # fmt chunk size
	_append_u16(out, 1)           # PCM
	_append_u16(out, 1)           # mono
	_append_u32(out, RATE)
	_append_u32(out, RATE * 2)    # byte rate (1 ch * 2 bytes)
	_append_u16(out, 2)           # block align
	_append_u16(out, 16)          # bits per sample
	out.append_array("data".to_ascii_buffer())
	_append_u32(out, data.size())
	out.append_array(data)
	return out


func _append_u32(buf: PackedByteArray, v: int) -> void:
	buf.append(v & 0xFF)
	buf.append((v >> 8) & 0xFF)
	buf.append((v >> 16) & 0xFF)
	buf.append((v >> 24) & 0xFF)


func _append_u16(buf: PackedByteArray, v: int) -> void:
	buf.append(v & 0xFF)
	buf.append((v >> 8) & 0xFF)
