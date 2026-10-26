extends Node
## Procedural sound effects + a small generated music loop (no audio files).

const RATE := 22050
const MUSIC_RATE := 11025

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	_streams["pearl"] = _tones([1046.5, 1568.0], 0.08, 0.32)
	_streams["close"] = _tones([659.3, 987.8, 1318.5], 0.06, 0.3)
	_streams["win"] = _tones([523.3, 659.3, 784.0, 1046.5, 1318.5], 0.11, 0.33)
	_streams["star"] = _tones([1318.5, 1975.5], 0.1, 0.3)
	_streams["crash"] = _noise(0.45, 0.5, 0.25, 70.0)
	_streams["tick"] = _tones([440.0], 0.07, 0.3)
	_streams["click"] = _tones([880.0], 0.035, 0.25)
	_streams["boost"] = _sweep(300.0, 1200.0, 0.35, 0.3)
	_streams["slow"] = _sweep(900.0, 250.0, 0.45, 0.28)
	_streams["power"] = _tones([523.3, 784.0, 1046.5, 1568.0], 0.06, 0.3)
	_streams["shield_pop"] = _noise(0.3, 0.45, 0.6, 180.0)
	_streams["buy"] = _tones([784.0, 1046.5, 1318.5, 2093.0], 0.07, 0.3)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -13.0
	add_child(_music)
	call_deferred("_start_music")


func play(sound_name: String, pitch := 1.0) -> void:
	if not Save.sound or not _streams.has(sound_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound_name]
			p.pitch_scale = pitch
			p.play()
			return


func vibrate(ms: int) -> void:
	if Save.vibe:
		Input.vibrate_handheld(ms)


func set_music(on: bool) -> void:
	if on and _music.stream and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()


func _start_music() -> void:
	_music.stream = _make_music()
	set_music(Save.music)


# ------------------------------------------------------------------ synthesis

func _wav(samples: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _tones(freqs: Array, note_len: float, volume: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var n := int(RATE * note_len)
	for f in freqs:
		for i in n:
			var t := float(i) / RATE
			var env := minf(1.0, i / 150.0) * pow(1.0 - float(i) / n, 1.5)
			var s := sin(TAU * float(f) * t) + 0.3 * sin(TAU * float(f) * 2.0 * t)
			samples.append(s * env * volume)
	return _wav(samples)


func _sweep(f0: float, f1: float, length: float, volume: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var n := int(RATE * length)
	var phase := 0.0
	for i in n:
		var u := float(i) / n
		phase += TAU * lerpf(f0, f1, u * u) / RATE
		var env := minf(1.0, i / 300.0) * (1.0 - u)
		samples.append((sin(phase) + 0.4 * randf_range(-1.0, 1.0) * (1.0 - u)) * env * volume)
	return _wav(samples)


func _noise(length: float, volume: float, smooth: float, thump_hz: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var n := int(RATE * length)
	var last := 0.0
	for i in n:
		var env := pow(1.0 - float(i) / n, 2.0)
		last = lerpf(last, randf_range(-1.0, 1.0), smooth)
		var thump := sin(TAU * thump_hz * float(i) / RATE) * maxf(0.0, 1.0 - float(i) / (n * 0.3))
		samples.append((last * 0.8 + thump * 0.6) * env * volume)
	return _wav(samples)


## 8-second loop: soft pad (Am - F - C - G) + a gentle plucked arpeggio.
func _make_music() -> AudioStreamWAV:
	var chords := [
		[220.0, 261.6, 329.6], [174.6, 220.0, 261.6],
		[261.6, 329.6, 392.0], [196.0, 246.9, 293.7],
	]
	var seconds := 8.0
	var n := int(MUSIC_RATE * seconds)
	var per_chord := n / 4
	var samples := PackedFloat32Array()
	samples.resize(n)
	var step := int(MUSIC_RATE * 0.25)  # eighth notes at 120 bpm
	for i in n:
		var ci := mini(i / per_chord, 3)
		var chord: Array = chords[ci]
		var t := float(i) / MUSIC_RATE
		var local := float(i % per_chord) / per_chord
		var pad_env := minf(local * 6.0, 1.0) * minf((1.0 - local) * 6.0, 1.0)
		var pad := 0.0
		for f in chord:
			pad += sin(TAU * float(f) * t) + 0.5 * sin(TAU * float(f) * 1.003 * t)
		var k := (i / step) % 3
		var note: float = float(chord[k]) * 2.0
		var pt := float(i % step) / MUSIC_RATE
		var pluck := sin(TAU * note * pt) * exp(-pt * 9.0)
		samples[i] = pad * pad_env * 0.06 + pluck * 0.22
	return _wav(samples, MUSIC_RATE, true)
