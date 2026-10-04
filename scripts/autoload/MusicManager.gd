extends Node











enum State{OPENING, BISTRO_PAN, MAIN, CHOICE, ENDING, MELTING}

const STEM_DIR: = "res://assets/audio/music_stems/"
const STEMS: = ["pad", "kick", "hihat", "snare", "bass", "chatter", "chatter_tension", "vinyl"]



const AUDIBLE: = {
	State.OPENING: ["pad", "kick", "vinyl"], 
	State.BISTRO_PAN: ["pad", "kick", "hihat", "vinyl"], 
	State.MAIN: ["pad", "kick", "hihat", "snare", "bass", "chatter", "vinyl"], 
	State.CHOICE: ["kick", "bass", "chatter_tension", "vinyl"], 
	State.ENDING: ["kick", "hihat", "snare", "chatter", "vinyl"], 


	State.MELTING: ["bass", "kick"], 
}



const LINE_TRIGGERS: = [
	{"needle": "this is the location she sent me alright", "state": State.BISTRO_PAN}, 
	{"needle": "you are actually here", "state": State.MAIN}, 
	{"needle": "feels like i'm melting", "state": State.MELTING}, 
	{"needle": "whoopsie", "state": State.MAIN}, 
]

@export_group("Tuning")

@export var default_fade: float = 1.0
@export_group("Debug")

@export var debug_hotkeys: bool = true



var fade_for: = {
	Vector2i(State.OPENING, State.BISTRO_PAN): 1.7, 
	Vector2i(State.BISTRO_PAN, State.MAIN): 2.5, 
	Vector2i(State.MAIN, State.CHOICE): 0.4, 
	Vector2i(State.CHOICE, State.MAIN): 1.0, 
	Vector2i(State.MAIN, State.ENDING): 2.5, 
	Vector2i(State.MAIN, State.MELTING): 0.0, 
	Vector2i(State.MELTING, State.MAIN): 1.8, 
}

const BUS: = "Music"
const AUDIBLE_DB: = 0.0
const MUTED_DB: = -80.0


const BISTRO_DUCK_DB: = -10.0

var _players: Dictionary = {}
var _tweens: Dictionary = {}
var _stem_target: Dictionary = {}
var _state: int = State.OPENING
var _applied_once: bool = false
var _duck_tween: Tween


var _user_db: float = 0.0
var _duck_db: float = 0.0

func _ready() -> void :
	_ensure_bus()
	_make_players()



	DialogueManager.node_entered.connect(_on_node_entered)
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.choices_shown.connect(_on_choices_shown)
	DialogueManager.run_ended.connect(_on_run_ended)
	if AudioServer.get_bus_index(BUS) == -1:
		push_error("[MusicManager] '%s' bus missing!" % BUS)

	set_user_volume_linear(float(MetaState.flags.get("music_volume", 1.0)))





func set_user_volume_linear(v: float) -> void :
	v = clampf(v, 0.0, 1.0)
	_user_db = -80.0 if v <= 0.0 else linear_to_db(v)
	_apply_music_bus()

func get_user_volume_linear() -> float:
	return db_to_linear(_user_db) if _user_db > -80.0 else 0.0

func _apply_music_bus() -> void :
	var idx: = AudioServer.get_bus_index(BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, _user_db + _duck_db)




func begin(state: int = State.OPENING) -> void :
	_play_all()
	set_music_state(state, 0.0)

func _ensure_playing() -> void :
	for s in STEMS:
		var p: AudioStreamPlayer = _players[s]
		if p.stream != null and not p.playing:
			p.play()




func _ensure_bus() -> void :
	if AudioServer.get_bus_index(BUS) == -1:
		var idx: = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")

func _make_players() -> void :
	for s in STEMS:
		var p: = AudioStreamPlayer.new()
		p.name = "Stem_" + s
		p.bus = BUS
		p.volume_db = MUTED_DB
		var stream: AudioStream = load(STEM_DIR + s + ".wav")
		if stream == null:
			push_error("MusicManager: missing stem '%s'" % s)
		elif stream is AudioStreamWAV:


			var wav: = stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
		p.stream = stream
		add_child(p)
		_players[s] = p

func _play_all() -> void :

	for s in STEMS:
		if _players[s].stream != null:
			_players[s].play()




func set_music_state(next: int, fade_override: float = -1.0) -> void :
	if next == _state and _applied_once:
		return
	var prev: = _state
	_state = next
	_applied_once = true
	var dur: = fade_override
	if dur < 0.0:
		dur = fade_for.get(Vector2i(prev, next), default_fade)
	print("[MusicManager] %s -> %s (%.2fs)" % [State.keys()[prev], State.keys()[next], dur])
	for s in STEMS:
		var target: float = AUDIBLE_DB if AUDIBLE[next].has(s) else MUTED_DB




		if _stem_target.has(s) and is_equal_approx(_stem_target[s], target):
			continue
		_stem_target[s] = target
		_fade_stem(s, target, dur)

	_duck_music(BISTRO_DUCK_DB if next == State.BISTRO_PAN else 0.0, dur)



func _duck_music(target_offset: float, dur: float) -> void :
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	if dur <= 0.0:
		_duck_db = target_offset
		_apply_music_bus()
		return
	_duck_tween = create_tween()
	_duck_tween.tween_method( func(v: float): _duck_db = v;_apply_music_bus(), _duck_db, target_offset, dur)

func _fade_stem(s: String, target_db: float, dur: float) -> void :
	var p: AudioStreamPlayer = _players[s]
	if _tweens.has(s) and _tweens[s] != null and _tweens[s].is_valid():
		_tweens[s].kill()
	if dur <= 0.0:
		p.volume_db = target_db
		return
	var t: = create_tween()
	t.tween_property(p, "volume_db", target_db, dur)
	_tweens[s] = t




func _on_node_entered(node_id: String) -> void :
	var kind: String = GameData.get_node_data(node_id).get("kind", "")

	if kind == "prey":
		set_music_state(State.ENDING)
	elif node_id == GameData.start_node:
		set_music_state(State.OPENING)
	elif _state == State.CHOICE:

		set_music_state(State.MAIN)







func _on_run_ended(kind: String, _info: Dictionary) -> void :
	if kind == "ending":
		set_music_state(State.ENDING)

func _on_line_shown(_speaker: String, text: String, _is_last: bool) -> void :
	var t: = text.to_lower()
	for trig in LINE_TRIGGERS:
		if t.find(trig["needle"]) != -1:
			set_music_state(trig["state"])
			return

func _on_choices_shown(_choices: Array) -> void :

	if _state != State.ENDING:
		set_music_state(State.CHOICE)




func _input(event: InputEvent) -> void :
	if not debug_hotkeys:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5: set_music_state(State.OPENING)
			KEY_F6: set_music_state(State.BISTRO_PAN)
			KEY_F7: set_music_state(State.MAIN)
			KEY_F8: set_music_state(State.CHOICE)
			KEY_F9: set_music_state(State.ENDING)
