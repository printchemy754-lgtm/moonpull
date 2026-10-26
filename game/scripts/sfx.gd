extends Node
## Tiny procedural sound effects — no audio assets needed.

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_streams["pearl"] = _tones([1046.5, 1568.0], 0.09, 0.35)
	_streams["close"] = _tones([659.3, 987.8, 1318.5], 0.06, 0.3)
	_streams["win"] = _tones([523.3, 659.3, 784.0, 1046.5], 0.13, 0.35)
	_streams["crash"] = _noise(0.45, 0.5)
	_streams["tick"] = _tones([440.0], 0.07, 0.3)
	for i in 5:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound_name: String) -> void:
	if not _streams.has(sound_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound_name]
			p.play()
			return


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
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


func _noise(length: float, volume: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var n := int(RATE * length)
	var last := 0.0
	for i in n:
		var env := pow(1.0 - float(i) / n, 2.0)
		last = lerpf(last, randf_range(-1.0, 1.0), 0.25)  # low-passed noise = "splash/crunch"
		var thump := sin(TAU * 70.0 * float(i) / RATE) * maxf(0.0, 1.0 - float(i) / (n * 0.3))
		samples.append((last * 0.8 + thump * 0.6) * env * volume)
	return _wav(samples)
