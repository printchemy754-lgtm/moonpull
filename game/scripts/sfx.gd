extends Node
## Procedural sound effects + the synthwave soundtrack (music/*.ogg, made by
## tools/make_music.py). Menu and run tracks crossfade; FEVER speeds the music up.

const RATE := 22050
const MUSIC_RATE := 11025

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _tracks := {}
var _players_m := {}
var _mode := ""
var _req := ""
var _fever := false
const MUSIC_DB := -9.0


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
	for key in ["menu", "run", "halloween", "christmas"]:
		var st: AudioStreamOggVorbis = load("res://music/%s.ogg" % key)
		st.loop = true
		_tracks[key] = st
		var mp := AudioStreamPlayer.new()
		mp.stream = st
		mp.volume_db = -80.0
		add_child(mp)
		_players_m[key] = mp
	call_deferred("music_mode", "menu")


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
	for key in _players_m:
		var mp: AudioStreamPlayer = _players_m[key]
		if not on:
			mp.stop()
	if on:
		refresh_season()


## Season changed in Settings: switch soundtrack.
func refresh_season() -> void:
	var m := _req
	_req = ""
	_mode = ""
	music_mode(m if m != "" else "menu")


## "menu" (chill) or "run" (driving). Crossfades between the two.
## During Halloween / Christmas the seasonal track plays everywhere.
func music_mode(req: String) -> void:
	if req == _req and _mode != "":
		return
	_req = req
	var mode := req
	if Season.current() != "":
		mode = Season.current()
	if mode == _mode or not _players_m.has(mode):
		return
	_mode = mode
	if not Save.music:
		return
	for key in _players_m:
		var mp: AudioStreamPlayer = _players_m[key]
		if key == mode:
			if not mp.playing:
				mp.volume_db = -40.0
				mp.play()
			mp.create_tween().tween_property(mp, "volume_db", MUSIC_DB, 0.6)
		elif mp.playing:
			var tw := mp.create_tween()
			tw.tween_property(mp, "volume_db", -60.0, 0.8)
			tw.tween_callback(mp.stop)


## FEVER: the run track speeds up a little.
func fever(on: bool) -> void:
	if on == _fever:
		return
	_fever = on
	for key in ["run", "halloween", "christmas"]:
		var mp: AudioStreamPlayer = _players_m[key]
		mp.create_tween().tween_property(mp, "pitch_scale", 1.08 if on else 1.0, 0.3)


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
