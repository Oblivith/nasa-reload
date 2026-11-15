# SI assistance metadata: This code used the help of SI.
extends SceneTree

const OUT := "res://assets/audio/"
const RATE := 22050

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 1961
	var started := Time.get_ticks_msec()
	var made := 0
	for entry: Array in _catalogue():
		var samples: PackedFloat32Array = entry[1]
		if str(entry[0]).begins_with("amb_") or str(entry[0]).begins_with("loop_"):
			samples = _seamless(samples, 0.35)
		_save(str(entry[0]), samples, float(entry[2]))
		made += 1
	print("gen_audio: wrote %d files to %s in %d ms" % [made, OUT, Time.get_ticks_msec() - started])
	quit()

func _catalogue() -> Array:
	return [
		["amb_hum", _hum(5.0), 0.5],
		["amb_air", _air(6.0), 0.55],
		["amb_office", _office(8.0, 5.0), 0.6],
		["amb_typing", _office(8.0, 13.0), 0.7],
		["amb_ibm", _ibm(8.0), 0.65],
		["amb_mission", _mission(10.0), 0.6],
		["amb_bay", _bay(9.0), 0.65],
		["amb_tunnel", _tunnel(6.0), 0.55],
		["amb_cafe", _cafe(9.0), 0.6],
		["amb_lobby", _lobby(9.0), 0.5],
		["amb_hiss", _hiss(5.0), 0.35],
		["loop_lift", _lift_motor(3.0), 0.7],
		["loop_teletype", _teletype(3.0), 0.7],
		["loop_tape", _tape(4.0), 0.5],
		["loop_clock", _clock(2.0), 0.5],
		["loop_crane", _crane(4.0), 0.6],
		["loop_printer", _printer(4.0), 0.6],
		["loop_coffee", _coffee(4.0), 0.5],
		["door_open", _door_open(), 0.7],
		["door_close", _door_close(), 0.8],
		["door_locked", _door_locked(), 0.75],
		["lift_ding", _ding(), 0.7],
		["lift_door", _lift_door(), 0.6],
		["phone_ring", _phone(), 0.7],
		["pa_chime", _pa(), 0.7],
		["vending", _vending(), 0.7],
		["step_lino_1", _step(900.0, 0.05, 0.5, 0.0), 0.6], ["step_lino_2", _step(1050.0, 0.045, 0.5, 0.0), 0.6],
		["step_concrete_1", _step(1600.0, 0.035, 0.7, 0.0), 0.6], ["step_concrete_2", _step(1400.0, 0.04, 0.7, 0.0), 0.6],
		["step_carpet_1", _step(320.0, 0.07, 0.25, 0.0), 0.5], ["step_carpet_2", _step(280.0, 0.08, 0.25, 0.0), 0.5],
		["step_metal_1", _step(1800.0, 0.04, 0.5, 1.0), 0.6], ["step_metal_2", _step(2000.0, 0.04, 0.5, 0.85), 0.6],
		["step_raised_1", _step(500.0, 0.07, 0.4, 0.35), 0.6], ["step_raised_2", _step(560.0, 0.065, 0.4, 0.3), 0.6],
	]

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

func _noise(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		b[i] = _rng.randf_range(-1.0, 1.0)
	return b

func _lp(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y
	return b

func _hp(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] -= y
	return b

func _band(seconds: float, lo: float, hi: float) -> PackedFloat32Array:
	return _hp(_lp(_noise(seconds), hi), lo)

func _gain(b: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in b.size():
		b[i] *= g
	return b

func _mix(into: PackedFloat32Array, src: PackedFloat32Array, at_seconds: float = 0.0, g: float = 1.0) -> void:
	var start := int(at_seconds * RATE)
	for i in src.size():
		var k := start + i
		if k >= into.size():
			k -= into.size()
		if k >= 0 and k < into.size():
			into[k] += src[i] * g

func _ping(freq: float, seconds: float, decay: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * freq * t) * exp(-t * decay)
	return b

func _clack(center: float, seconds: float, decay: float) -> PackedFloat32Array:
	var b := _band(seconds, center * 0.6, center * 1.6)
	for i in b.size():
		b[i] *= exp(-float(i) / RATE * decay)
	return b

func _tone(freq: float, seconds: float, harmonics: Array) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for h in harmonics.size():
			v += sin(TAU * freq * (h + 1) * t) * float(harmonics[h])
		b[i] = v
	return b

func _seamless(b: PackedFloat32Array, fade_seconds: float) -> PackedFloat32Array:
	var n := int(fade_seconds * RATE)
	var out := b.slice(0, b.size() - n)
	for i in n:
		var k := float(i) / n
		out[i] = out[i] * k + b[b.size() - n + i] * (1.0 - k)
	return out

func _save(file: String, b: PackedFloat32Array, peak: float) -> void:
	var top := 0.0001
	for v in b:
		top = maxf(top, absf(v))
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] / top * peak, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(OUT + file + ".wav")

func _hum(s: float) -> PackedFloat32Array:
	var b := _tone(120.0, s, [1.0, 0.45, 0.3, 0.12, 0.1, 0.05])
	_mix(b, _gain(_band(s, 2500.0, 6000.0), 0.12))
	return b

func _air(s: float) -> PackedFloat32Array:
	return _lp(_lp(_noise(s), 260.0), 400.0)

func _office(s: float, keys_per_second: float) -> PackedFloat32Array:
	var b := _gain(_air(s), 2.0)
	_mix(b, _gain(_tone(120.0, s, [1.0, 0.4, 0.2]), 0.035))
	var t := 0.2
	while t < s - 0.1:
		if _rng.randf() < 0.12:
			t += _rng.randf_range(0.3, 1.1)
			if _rng.randf() < 0.4:
				_mix(b, _ping(2100.0, 0.5, 9.0), t, 0.16)
				_mix(b, _clack(700.0, 0.18, 14.0), t + 0.12, 0.3)
		_mix(b, _clack(_rng.randf_range(2600.0, 4200.0), 0.03, 160.0), t, _rng.randf_range(0.25, 0.55))
		t += _rng.randf_range(0.6, 1.5) / keys_per_second
	return b

func _ibm(s: float) -> PackedFloat32Array:
	var b := _gain(_band(s, 300.0, 1400.0), 0.5)
	_mix(b, _gain(_tone(60.0, s, [1.0, 0.5, 0.35, 0.2]), 0.12))
	_mix(b, _gain(_tone(3150.0, s, [1.0]), 0.012))
	var t := 0.1
	while t < s - 0.1:
		if _rng.randf() < 0.3:
			for k in _rng.randi_range(4, 14):
				_mix(b, _clack(3200.0, 0.012, 300.0), t + k * 0.022, 0.2)
			t += 0.4
		_mix(b, _clack(1800.0, 0.02, 220.0), t, _rng.randf_range(0.12, 0.3))
		t += _rng.randf_range(0.08, 0.5)
	return b

func _mumble(seconds: float, pitch: float) -> PackedFloat32Array:
	var b := _band(seconds, pitch * 0.7, pitch * 2.6)
	var phase := _rng.randf() * TAU
	for i in b.size():
		var t := float(i) / RATE
		var syll := maxf(0.0, sin(TAU * 4.6 * t + phase) * 0.7 + sin(TAU * 2.9 * t) * 0.5)
		var edge := minf(1.0, minf(t, seconds - t) * 12.0)
		b[i] *= syll * edge
	return b

func _mission(s: float) -> PackedFloat32Array:
	var b := _gain(_air(s), 1.6)
	_mix(b, _gain(_tone(60.0, s, [1.0, 0.3]), 0.05))
	var t := 0.4
	while t < s - 2.2:
		var length := _rng.randf_range(0.8, 1.9)
		_mix(b, _mumble(length, _rng.randf_range(480.0, 760.0)), t, 0.4)
		_mix(b, _gain(_tone(2475.0, 0.22, [1.0]), 0.5), t + length + 0.05, 0.06)
		t += length + _rng.randf_range(0.7, 2.0)
	for k in 5:
		_mix(b, _ping(_rng.randf_range(900.0, 1500.0), 0.12, 30.0), _rng.randf_range(0.0, s - 0.3), 0.05)
	return b

func _bay(s: float) -> PackedFloat32Array:
	var b := _gain(_lp(_noise(s), 140.0), 3.0)
	var whine := _buf(s)
	for i in whine.size():
		var t := float(i) / RATE
		whine[i] = sin(TAU * (88.0 + sin(TAU * 0.11 * t) * 3.0) * t) * 0.5 + sin(TAU * 176.0 * t) * 0.2
	_mix(b, whine, 0.0, 0.1)
	for k in 4:
		var at := _rng.randf_range(0.2, s - 1.2)
		var clank := _ping(_rng.randf_range(520.0, 760.0), 0.9, 6.0)
		_mix(clank, _ping(_rng.randf_range(1300.0, 1900.0), 0.9, 9.0), 0.0, 0.6)
		_mix(b, clank, at, 0.1)
	for k in 9:
		_mix(b, _clack(1200.0, 0.05, 80.0), 3.0 + k * 0.21 + _rng.randf_range(0.0, 0.02), 0.08)
	return b

func _tunnel(s: float) -> PackedFloat32Array:
	var b := _gain(_tone(60.0, s, [1.0, 0.6, 0.25, 0.2]), 0.3)
	_mix(b, _gain(_band(s, 500.0, 2500.0), 0.2))
	return b

func _cafe(s: float) -> PackedFloat32Array:
	var b := _gain(_air(s), 1.5)
	for voice in 5:
		var t := _rng.randf_range(0.0, 1.5)
		while t < s - 1.6:
			var length := _rng.randf_range(0.6, 1.5)
			_mix(b, _mumble(length, _rng.randf_range(260.0, 520.0)), t, 0.16)
			t += length + _rng.randf_range(0.2, 1.6)
	for k in 6:
		_mix(b, _ping(_rng.randf_range(3200.0, 5200.0), 0.25, 22.0), _rng.randf_range(0.0, s - 0.3), 0.06)
	_mix(b, _gain(_tone(100.0, s, [1.0, 0.3]), 0.03))
	return b

func _lobby(s: float) -> PackedFloat32Array:
	var b := _gain(_air(s), 1.4)
	for k in 5:
		var at := _rng.randf_range(0.2, s - 0.6)
		for n in _rng.randi_range(2, 4):
			var chirp := _buf(0.09)
			var base := _rng.randf_range(3200.0, 4600.0)
			for i in chirp.size():
				var t := float(i) / RATE
				chirp[i] = sin(TAU * (base + 9000.0 * t) * t) * sin(PI * t / 0.09)
			_mix(b, chirp, at + n * 0.13, 0.02)
	return b

func _hiss(s: float) -> PackedFloat32Array:
	return _hp(_lp(_noise(s), 7000.0), 2500.0)

func _lift_motor(s: float) -> PackedFloat32Array:
	var b := _gain(_tone(72.0, s, [1.0, 0.5, 0.3, 0.15]), 0.4)
	_mix(b, _gain(_lp(_noise(s), 300.0), 1.2))
	_mix(b, _gain(_tone(410.0, s, [1.0]), 0.03))
	return b

func _teletype(s: float) -> PackedFloat32Array:
	var b := _gain(_tone(60.0, s, [1.0, 0.4]), 0.05)
	var t := 0.0
	while t < s - 0.1:
		_mix(b, _clack(2200.0, 0.03, 150.0), t, _rng.randf_range(0.5, 0.9))
		_mix(b, _clack(260.0, 0.04, 90.0), t, 0.35)
		t += 0.1 if _rng.randf() < 0.9 else 0.3
	return b

func _tape(s: float) -> PackedFloat32Array:
	var b := _gain(_band(s, 400.0, 1800.0), 0.5)
	var t := 0.2
	while t < s - 0.2:
		_mix(b, _clack(1500.0, 0.03, 140.0), t, 0.5)
		t += _rng.randf_range(0.2, 0.9)
	return b

func _clock(s: float) -> PackedFloat32Array:
	var b := _buf(s + 0.35)
	_mix(b, _clack(3000.0, 0.03, 220.0), 0.05, 1.0)
	_mix(b, _clack(2300.0, 0.03, 220.0), 1.05, 0.8)
	return b

func _crane(s: float) -> PackedFloat32Array:
	var b := _buf(s)
	for i in b.size():
		var t := float(i) / RATE
		var f := 96.0 + sin(TAU * 0.25 * t) * 4.0
		b[i] = (fmod(f * t, 1.0) - 0.5) * 0.5 + sin(TAU * f * 3.0 * t) * 0.15
	_lp(b, 900.0)
	_mix(b, _gain(_band(s, 800.0, 3000.0), 0.08))
	return b

func _printer(s: float) -> PackedFloat32Array:
	var b := _gain(_tone(60.0, s, [1.0, 0.5]), 0.05)
	var t := 0.0
	while t < s - 0.4:
		for k in _rng.randi_range(8, 20):
			_mix(b, _clack(1700.0, 0.02, 200.0), t + k * 0.018, 0.6)
		_mix(b, _clack(400.0, 0.1, 30.0), t + 0.38, 0.4)
		t += _rng.randf_range(0.5, 0.9)
	return b

func _coffee(s: float) -> PackedFloat32Array:
	var b := _gain(_band(s, 300.0, 900.0), 0.08)
	var t := 0.1
	while t < s - 0.2:
		var blip := _buf(0.07)
		var base := _rng.randf_range(260.0, 520.0)
		for i in blip.size():
			var u := float(i) / RATE
			blip[i] = sin(TAU * (base + 2500.0 * u) * u) * sin(PI * u / 0.07)
		_mix(b, blip, t, 0.5)
		t += _rng.randf_range(0.12, 0.5)
	return b

func _door_open() -> PackedFloat32Array:
	var b := _buf(0.6)
	_mix(b, _clack(1800.0, 0.04, 120.0), 0.0, 0.9)
	_mix(b, _clack(700.0, 0.05, 90.0), 0.03, 0.6)
	var creak := _buf(0.4)
	for i in creak.size():
		var t := float(i) / RATE
		creak[i] = sin(TAU * (240.0 + 160.0 * t) * t + sin(TAU * 31.0 * t) * 2.0) * sin(PI * t / 0.4) * 0.12
	_mix(b, creak, 0.1)
	return b

func _door_close() -> PackedFloat32Array:
	var b := _buf(0.5)
	_mix(b, _ping(85.0, 0.4, 16.0), 0.0, 1.0)
	_mix(b, _clack(500.0, 0.08, 50.0), 0.0, 0.7)
	_mix(b, _clack(2000.0, 0.03, 150.0), 0.06, 0.5)
	return b

func _door_locked() -> PackedFloat32Array:
	var b := _buf(0.6)
	for k in 4:
		_mix(b, _clack(1500.0, 0.035, 130.0), k * 0.09, 0.8)
		_mix(b, _clack(350.0, 0.05, 70.0), k * 0.09 + 0.01, 0.6)
	return b

func _ding() -> PackedFloat32Array:
	var b := _buf(1.4)
	_mix(b, _ping(1318.5, 1.4, 4.0), 0.0, 0.8)
	_mix(b, _ping(2637.0, 1.0, 7.0), 0.0, 0.3)
	_mix(b, _ping(3955.0, 0.5, 12.0), 0.0, 0.12)
	return b

func _lift_door() -> PackedFloat32Array:
	var b := _gain(_band(1.0, 200.0, 900.0), 0.5)
	for i in b.size():
		b[i] *= sin(PI * float(i) / b.size())
	_mix(b, _clack(300.0, 0.1, 40.0), 0.86, 1.0)
	return b

func _phone() -> PackedFloat32Array:
	var b := _buf(2.2)
	for burst: float in [0.0, 0.55]:
		var ring := _buf(0.42)
		for i in ring.size():
			var t := float(i) / RATE
			var clapper := 0.55 + 0.45 * signf(sin(TAU * 22.0 * t))
			ring[i] = (sin(TAU * 1350.0 * t) + sin(TAU * 1720.0 * t) * 0.8 + sin(TAU * 2900.0 * t) * 0.3) * clapper * minf(1.0, (0.42 - t) * 30.0)
		_mix(b, ring, burst)
	for i in b.size():
		b[i] *= 1.0
	return b

func _pa() -> PackedFloat32Array:
	var b := _buf(4.6)
	var notes := [659.3, 523.3, 784.0]
	for k in 3:
		_mix(b, _ping(notes[k], 1.2, 3.5), k * 0.42, 0.6)
		_mix(b, _ping(notes[k] * 2.0, 0.8, 6.0), k * 0.42, 0.15)
	var voice := _mumble(2.4, 520.0)
	_mix(b, _hp(voice, 500.0), 1.9, 0.55)
	return b

func _vending() -> PackedFloat32Array:
	var b := _buf(1.6)
	_mix(b, _clack(900.0, 0.05, 80.0), 0.0, 0.7)
	_mix(b, _gain(_band(0.7, 200.0, 700.0), 0.3), 0.15)
	_mix(b, _ping(120.0, 0.5, 9.0), 0.95, 1.0)
	_mix(b, _clack(600.0, 0.12, 30.0), 0.95, 0.8)
	return b

func _step(center: float, seconds: float, hardness: float, ring: float) -> PackedFloat32Array:
	var b := _buf(0.28)
	_mix(b, _ping(95.0, 0.12, 40.0), 0.0, 0.8 - hardness * 0.3)
	_mix(b, _clack(center, seconds * 2.0, 1.0 / seconds), 0.0, 0.5 + hardness * 0.5)
	if ring > 0.0:
		for f: float in [center * 0.45, center * 0.78, center * 1.31]:
			_mix(b, _ping(f, 0.26, 16.0 - ring * 6.0), 0.0, 0.22 * ring)
	return b
