extends Node
## Áudio do jogo (autoload "Sfx"): barramentos Music/SFX, pool de players, música em loop.
## Os arquivos vêm de tools/gen_audio.gd (assets/audio/*.wav).

const NAMES: Array[String] = ["coin", "coin_big", "build", "upgrade", "ding", "click", "open", "close", "levelup", "goal", "vip", "bad", "star", "rush", "boo"]
const POOL := 12

var sfx_on := true
var music_on := true
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _last_ms: Dictionary = {}
var _combo := 0
var _combo_ms := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for n in NAMES:
		var s := load("res://assets/audio/%s.wav" % n) as AudioStream
		if s != null:
			_streams[n] = s
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	var ms := load("res://assets/audio/music.wav") as AudioStreamWAV
	if ms != null:
		ms.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ms.loop_begin = 0
		ms.loop_end = ms.data.size() / 2 - 1
		_music.stream = ms

## Solta os sons ao fechar (sem isso o modo headless/áudio "dummy" avisa de objetos não liberados).
func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null
	for p in _pool:
		p.stop()
		p.stream = null
	_streams.clear()

func _setup_buses() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -9.0)
	var sfx_i := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_i) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.35
		rv.damping = 0.6
		rv.wet = 0.1
		rv.dry = 1.0
		AudioServer.add_bus_effect(sfx_i, rv)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _music != null:
			_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if _music != null:
			_music.stream_paused = false

func play(sound: StringName, pitch: float = 1.0, db: float = 0.0) -> void:
	if not sfx_on:
		return
	var key := String(sound)
	if not _streams.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(key, -1000)) < 45:          # evita empilhar o mesmo som
		return
	_last_ms[key] = now
	for p in _pool:
		if not p.playing:
			p.stream = _streams[key]
			p.pitch_scale = pitch
			p.volume_db = db
			p.play()
			return

## Moedas coletadas: o tom sobe a cada coleta seguida (cadeia).
func coin(amount: float) -> void:
	var now := Time.get_ticks_msec()
	_combo = _combo + 1 if now - _combo_ms < 1300 else 0
	_combo_ms = now
	var pitch := 1.0 + float(mini(_combo, 8)) * 0.055
	play(&"coin_big" if amount >= 50.0 else &"coin", pitch)

func start_music() -> void:
	if music_on and _music != null and _music.stream != null and not _music.playing:
		_music.play()

func set_sfx_enabled(v: bool) -> void:
	sfx_on = v

func set_music_enabled(v: bool) -> void:
	music_on = v
	if _music == null:
		return
	if v:
		start_music()
	else:
		_music.stop()
