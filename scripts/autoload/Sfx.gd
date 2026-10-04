extends Node









const BUS: = "SFX"
const DIR: = "res://assets/audio/sfx/"


const VOL: = {
	"choice_navigate": 0.0, 
	"choice_confirm": 0.0, 
	"cup": 10.0, 
	"jug": 15.0, 
	"trans": 0.0, 
	"longshot_ambience": 0.0, 
}

const POOL_SIZE: = 8

var _streams: Dictionary = {}
var _pool: Array = []
var _pool_i: int = 0
var _ambience: AudioStreamPlayer
var _amb_tween: Tween

func _ready() -> void :
	_ensure_bus()
	for n in VOL.keys():
		_streams[n] = load(DIR + n + ".wav")
	for i in range(POOL_SIZE):
		var p: = AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_pool.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS
	add_child(_ambience)

	set_user_volume_linear(float(MetaState.flags.get("sfx_volume", 1.0)))





func set_user_volume_linear(v: float) -> void :
	v = clampf(v, 0.0, 1.0)
	var idx: = AudioServer.get_bus_index(BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, -80.0 if v <= 0.0 else linear_to_db(v))

func get_user_volume_linear() -> float:
	var idx: = AudioServer.get_bus_index(BUS)
	if idx == -1:
		return 1.0
	var db: = AudioServer.get_bus_volume_db(idx)
	return 0.0 if db <= -80.0 else db_to_linear(db)

func _ensure_bus() -> void :
	if AudioServer.get_bus_index(BUS) == -1:
		var idx: = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")


func play(name: String) -> void :
	var s: AudioStream = _streams.get(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.volume_db = float(VOL.get(name, 0.0))
	p.play()


func play_ambience(name: String, fade: float = 1.0) -> void :
	var s: AudioStream = _streams.get(name)
	if s == null:
		return



	if _ambience.playing and _ambience.stream == s:
		_fade_ambience(float(VOL.get(name, -20.0)), fade, false)
		return
	if s is AudioStreamWAV:
		var w: = s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * float(w.mix_rate)))
	_ambience.stream = s
	_ambience.volume_db = -60.0
	_ambience.play()
	_fade_ambience(float(VOL.get(name, -20.0)), fade, false)


func stop_ambience(fade: float = 1.0) -> void :
	if not _ambience.playing:
		return
	_fade_ambience(-60.0, fade, true)

func _fade_ambience(target_db: float, dur: float, stop_after: bool) -> void :
	if _amb_tween and _amb_tween.is_valid():
		_amb_tween.kill()
	if dur <= 0.0:
		_ambience.volume_db = target_db
		if stop_after:
			_ambience.stop()
		return
	_amb_tween = create_tween()
	_amb_tween.tween_property(_ambience, "volume_db", target_db, dur)
	if stop_after:
		_amb_tween.tween_callback(_ambience.stop)
