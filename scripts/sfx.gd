extends Node
## Prozedural erzeugte Soundeffekte – kommt ohne Audiodateien aus.

const RATE := 22050
const VOICES := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["place"] = _make(0.09, func(t: float, _i: int) -> float:
		return sin(TAU * (180.0 - 900.0 * t) * t) * (1.0 - t / 0.09))
	_streams["explode"] = _make_noise(0.7, 0.92, 0.9)
	_streams["burn"] = _make_noise(0.25, 0.7, 0.35)
	_streams["thud"] = _make(0.18, func(t: float, _i: int) -> float:
		return (sin(TAU * 70.0 * t) + randf_range(-0.4, 0.4)) * (1.0 - t / 0.18) * 0.9)
	_streams["kick"] = _make(0.07, func(t: float, _i: int) -> float:
		return _square(420.0 - 2000.0 * t, t) * 0.35 * (1.0 - t / 0.07))
	_streams["pickup"] = _make(0.16, func(t: float, _i: int) -> float:
		var f := 660.0 if t < 0.05 else (880.0 if t < 0.1 else 1320.0)
		return _square(f, t) * 0.3)
	_streams["skull"] = _make(0.35, func(t: float, _i: int) -> float:
		return _square(200.0 - 300.0 * t + 30.0 * sin(t * 60.0), t) * 0.3 * (1.0 - t / 0.35))
	_streams["death"] = _make(0.8, func(t: float, _i: int) -> float:
		return _square(880.0 * pow(0.08, t / 0.8), t) * 0.3 * (1.0 - t / 0.8))
	_streams["tick"] = _make(0.08, func(t: float, _i: int) -> float:
		return _square(990.0, t) * 0.25 * (1.0 - t / 0.08))
	_streams["go"] = _make(0.3, func(t: float, _i: int) -> float:
		return _square(1320.0, t) * 0.25 * (1.0 - t / 0.3))
	_streams["hurry"] = _make(0.9, func(t: float, _i: int) -> float:
		var on := fmod(t, 0.3) < 0.18
		return _square(1100.0 if fmod(t, 0.6) < 0.3 else 880.0, t) * (0.25 if on else 0.0))
	_streams["win"] = _make(1.0, func(t: float, _i: int) -> float:
		var notes := [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0]
		var n: float = notes[mini(int(t / 0.14), notes.size() - 1)]
		return _square(n, t) * 0.25 * (1.0 if t < 0.84 else (1.0 - t) / 0.16))
	_streams["select"] = _make(0.05, func(t: float, _i: int) -> float:
		return _square(1500.0, t) * 0.2)


func play(name: String, volume_db := 0.0) -> void:
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.play()


static func _square(freq: float, t: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0


func _make(length: float, gen: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(gen.call(float(i) / RATE, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 26000.0))
	return _wav(data)


func _make_noise(length: float, smooth: float, volume: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		# Tiefpass-gefiltertes Rauschen, das langsam dumpfer und leiser wird.
		var a := smooth + (1.0 - smooth) * 0.5 * (1.0 - t)
		y = y * a + randf_range(-1.0, 1.0) * (1.0 - a)
		var v := clampf(y * 4.0 * volume * pow(1.0 - t, 1.6), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
