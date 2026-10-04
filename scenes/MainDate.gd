extends Node2D













const ART_W: = 3840.0
const ART_H: = 2160.0
const POSES: = ["idle", "happy", "neutral", "drink", "bleh", "trans1", "trans2", "trans3", "trans4", "soy", "sad", "smug", "smile"]

@export_group("Beat timing")

@export var read_hold: float = 0.7

@export var waiter_in: float = 1.0
@export var drop_hold: float = 2.0

@export var waiter_leave_hold: float = 1.0

@export var drink_hold: float = 2.0

@export var thankyou_hold: float = 1.5

@export var bleh_hold: float = 0.5

@export var transform_fps: float = 4.0

@export var trans4_hold: float = 3.0

@export_group("Candle glow")
@export var candle_glow_enabled: bool = true

@export var candle_glow_pos: Vector2 = Vector2(0.44, 0.85)
@export var candle_glow_scale: float = 1.6
@export var candle_glow_color: Color = Color(1.0, 0.72, 0.38)
@export var candle_glow_base_alpha: float = 0.3

@export_group("Coffee droplet effect")
@export var coffee_effect_enabled: bool = true

@export var coffee_effect_pos: Vector2 = Vector2(0.5, 0.5)

@export_group("Waiter entrance")


@export var waiter_slide_dist: float = 1300.0

@export var waiter_enter_time: float = 0.4

@export var waiter_exit_time: float = 0.3

@export var waiter_squash_in: float = 0.09
@export var waiter_squash_out: float = 0.12

@export var waiter_pause_before_prop: float = 0.15

@export_group("Idle life")




@export var idle_enabled: bool = true


@export var idle_vert_amp: float = 0.0

@export var idle_horz_amp: float = 0.0


@export var idle_vert_period_a: float = 4.0
@export var idle_vert_period_b: float = 2.7
@export var idle_horz_period: float = 5.6

@export_group("Debug")



@export var debug_preview: bool = false

@onready var idimya: Node2D = $Idimya
@onready var table: Sprite2D = $Table
@onready var menu: Sprite2D = $Menu
@onready var cup: Sprite2D = $Cup
@onready var jug: Sprite2D = $Jug
@onready var waiter: Sprite2D = $Waiter
@onready var candle_glow: Sprite2D = $CandleGlow
@onready var coffee: CPUParticles2D = $CoffeeDroplets

var _poses: Dictionary = {}
var _current_pose: String = "idle"
var _opening_active: bool = true
var _in_node0: bool = false
var _beat_running: bool = false
var _prey_started: bool = false
var _flicker_t: float = 0.0
var _pending_beat: = Callable()






const _SQUASH_BIGGER_POSES: = ["happy", "bleh", "drink", "soy", "smug", "sad"]


const _DEF_DUR: = 0.15
const _DEF_MID: = 0.06
const _DEF_OUT: = 0.11

const _DEF_SQUASH_D: = Vector2(0.008, -0.008)
const _DEF_OVERSHOOT_D: = Vector2(-0.003, 0.004)
const _DEF_BIG: = 1.0
const _DEF_BIGGER: = 1.4
var _base_pos: = Vector2.ZERO
var _idle_t: float = 0.0
var _deform_active: bool = false
var _deform_t: float = 0.0
var _deform_amp: float = 1.0
var _deform_dur_scale: float = 1.0
var _deform_no_settle: bool = false
var _suppress_line_pulse: bool = false


const _WAITER_SQUASH: = Vector2(1.03, 0.992)
var _waiter_base: = Vector2.ZERO
var _waiter_tween: Tween





const EXPRESSIONS_PATH: = "res://data/expressions.json"
var _expr_map: Dictionary = {}

func _ready() -> void :

	var k: = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)) / ART_W
	scale = Vector2(k, k)
	_base_pos = idimya.position
	_waiter_base = waiter.position
	for c in idimya.get_children():
		if c is Sprite2D:
			_poses[c.name] = c
	_load_expressions()
	_position_effects()
	_apply_initial_state()
	set_process_input(true)
	if not debug_preview:
		DialogueManager.line_shown.connect(_on_line_shown)
		DialogueManager.node_entered.connect(_on_node_entered)
		DialogueManager.choices_shown.connect(_on_choices_shown)


		var ui: = get_tree().get_first_node_in_group("dialogue_box")
		if ui and ui.has_signal("user_advanced"):
			ui.user_advanced.connect(_on_user_advanced)
		if ui and ui.has_signal("fast_forward_changed"):
			ui.fast_forward_changed.connect(_on_fast_forward_changed)



		_catch_up_current_line()






func _catch_up_current_line() -> void :
	var lines: Array = DialogueManager.current_node().get("lines", [])
	var idx: int = DialogueManager._line_index
	if idx < 0 or idx >= lines.size():
		return
	var line: Dictionary = lines[idx]
	var speaker: = str(line.get("speaker", "you"))
	var node: = DialogueManager.current_id
	_suppress_line_pulse = true
	_on_line_shown(speaker, str(line.get("text", "")), idx == lines.size() - 1)
	_suppress_line_pulse = false
	if speaker != "idimya":
		return




	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		return

	_set_dialogue_visible(false)
	_lock(true)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return
	_set_dialogue_visible(true)
	_lock(false)

	if DialogueManager.current_id == node and DialogueManager._line_index == idx\
	and not _beat_running and not _prey_started:
		_pulse_squash(_current_pose)

func _apply_initial_state() -> void :
	_reset_life()
	set_idimya_pose("idle")
	table.visible = true
	menu.visible = true
	$Candle.visible = true
	candle_glow.visible = candle_glow_enabled
	cup.visible = false
	jug.visible = false
	waiter.visible = false
	_reset_waiter()
	coffee.emitting = false





func enter_post_intro() -> void :
	_opening_active = false
	_in_node0 = false
	_prey_started = false
	_beat_running = false
	_pending_beat = Callable()
	_apply_initial_state()

func _position_effects() -> void :
	candle_glow.position = candle_glow_pos * Vector2(ART_W, ART_H)
	candle_glow.self_modulate = Color(candle_glow_color, candle_glow_base_alpha)
	candle_glow.scale = Vector2(candle_glow_scale, candle_glow_scale)
	coffee.position = coffee_effect_pos * Vector2(ART_W, ART_H)




func set_idimya_pose(pose: String) -> void :
	if not _poses.has(pose):
		push_warning("MainDate: no pose '%s'" % pose)
		return
	for name in _poses:
		_poses[name].visible = (name == pose)
	_current_pose = pose

func show_prop(prop: String) -> void :
	_prop(prop).visible = true

func hide_prop(prop: String) -> void :
	_prop(prop).visible = false

func _prop(prop: String) -> Sprite2D:
	match prop:
		"cup": return cup
		"jug": return jug
		_:
			push_warning("MainDate: no prop '%s'" % prop)
			return cup

func show_waiter() -> void :
	waiter.visible = true

func hide_waiter() -> void :
	waiter.visible = false







func _apply_waiter(slide_x: float, s: Vector2) -> void :
	waiter.scale = s
	var pivot: = Vector2(ART_W, ART_H)
	waiter.position = _waiter_base + Vector2(slide_x, 0.0)\
	+ Vector2(pivot.x * (1.0 - s.x), pivot.y * (1.0 - s.y))


func _reset_waiter() -> void :
	if _waiter_tween and _waiter_tween.is_valid():
		_waiter_tween.kill()
	_apply_waiter(0.0, Vector2.ONE)




func _waiter_enter() -> void :
	if _waiter_tween and _waiter_tween.is_valid():
		_waiter_tween.kill()
	waiter.visible = true
	if _fast_forward:
		_apply_waiter(0.0, Vector2.ONE)
		return
	_apply_waiter(waiter_slide_dist, Vector2.ONE)
	_waiter_tween = create_tween()
	_waiter_tween.tween_method( func(v: float): _apply_waiter(v, Vector2.ONE), 
		waiter_slide_dist, 0.0, waiter_enter_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_waiter_tween.tween_method( func(v: float): _apply_waiter(0.0, Vector2.ONE.lerp(_WAITER_SQUASH, v)), 
		0.0, 1.0, waiter_squash_in)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_waiter_tween.tween_method( func(v: float): _apply_waiter(0.0, _WAITER_SQUASH.lerp(Vector2.ONE, v)), 
		0.0, 1.0, waiter_squash_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _waiter_tween.finished


func _waiter_exit() -> void :
	if _waiter_tween and _waiter_tween.is_valid():
		_waiter_tween.kill()
	if _fast_forward or not waiter.visible:
		waiter.visible = false
		_reset_waiter()
		return
	_apply_waiter(0.0, Vector2.ONE)
	_waiter_tween = create_tween()
	_waiter_tween.tween_method( func(v: float): _apply_waiter(v, Vector2.ONE), 
		0.0, waiter_slide_dist, waiter_exit_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _waiter_tween.finished
	waiter.visible = false
	_reset_waiter()

func play_coffee_bleh_effect() -> void :
	if not coffee_effect_enabled:
		return
	coffee.emitting = false
	coffee.restart()
	coffee.emitting = true




func _lock(v: bool) -> void :
	if not debug_preview:
		DialogueManager.set_advance_locked(v)



var _fast_forward: bool = false
func _on_fast_forward_changed(active: bool) -> void :
	_fast_forward = active



func _bh(seconds: float) -> float:
	return 0.0 if _fast_forward else seconds


func _set_dialogue_visible(v: bool) -> void :
	if debug_preview:
		return
	var ui: = get_tree().get_first_node_in_group("dialogue_box")
	if ui:
		ui.visible = v




func _drop_beat(prop: String, keep_waiter: bool = false, hold: float = -1.0) -> void :
	if _beat_running: return
	_beat_running = true
	_lock(true)
	_set_dialogue_visible(false)
	await _waiter_enter()
	await get_tree().create_timer(_bh(waiter_pause_before_prop)).timeout
	show_prop(prop)
	Sfx.play(prop)
	await get_tree().create_timer(_bh(hold if hold >= 0.0 else drop_hold)).timeout
	if not keep_waiter:
		await _waiter_exit()
	_set_dialogue_visible(true)
	_lock(false)
	_beat_running = false
	if not debug_preview:
		DialogueManager.advance()



func _beat_waiter_leave() -> void :
	if _beat_running: return
	_beat_running = true
	_lock(true)
	_set_dialogue_visible(false)
	await get_tree().create_timer(_bh(waiter_leave_hold)).timeout
	await _waiter_exit()
	_set_dialogue_visible(true)
	_lock(false)
	_beat_running = false
	if not debug_preview:
		DialogueManager.advance()




func _beat_drink() -> void :
	if _beat_running: return
	_beat_running = true
	_lock(true)
	_set_dialogue_visible(false)
	await _waiter_exit()
	hide_prop("jug")
	set_idimya_pose("drink")
	_pulse_squash("drink", true)
	await get_tree().create_timer(_bh(drink_hold)).timeout
	show_prop("jug")
	Sfx.play("jug")
	_set_dialogue_visible(true)
	_lock(false)
	_beat_running = false
	if not debug_preview:


		DialogueManager.advance()






func play_transformation() -> void :
	if _beat_running or _prey_started: return
	_prey_started = true
	_beat_running = true
	_lock(true)
	Sfx.play("trans")
	var ft: = 1.0 / maxf(transform_fps, 0.1)
	for frame in ["trans1", "trans2", "trans3", "trans4"]:
		set_idimya_pose(frame)
		if frame == "trans1":
			_pulse_squash(frame, true)

		await get_tree().create_timer(trans4_hold if frame == "trans4" else ft).timeout
	_lock(false)
	_beat_running = false


func _play_prey_from_node0() -> void :
	await play_transformation()
	if not debug_preview:
		DialogueManager.advance()







func _arm(cb: Callable) -> void :
	_pending_beat = cb
	_lock(true)


func _on_user_advanced() -> void :
	if _pending_beat.is_valid():
		var cb: = _pending_beat
		_pending_beat = Callable()
		cb.call()

func _on_line_shown(speaker: String, text: String, _is_last: bool) -> void :
	var t: = text.to_lower()
	var pose_before: = _current_pose
	_pending_beat = Callable()
	if _in_node0:
		set_idimya_pose("idle")
		if t.find("why? did you eat already") != -1:
			set_idimya_pose("neutral")
		elif t.find("you are not going anywhere") != -1:
			_arm(_play_prey_from_node0)
		_apply_sheet_override()
	elif not _opening_active:
		_apply_sheet_pose()
	else:
		set_idimya_pose("idle")
		if t.find("i like espressos") != -1:
			_arm( func(): _drop_beat("cup", true, drop_hold + 1.0))
		elif t.find("excuse me") != -1:
			set_idimya_pose("neutral")
		elif t.find("why is my espresso so small") != -1:
			set_idimya_pose("neutral")
		elif t.find("i want 10 of them") != -1:
			set_idimya_pose("idle")
		elif t.find("might just have a decaf") != -1:
			_arm(_beat_waiter_leave)
		elif t.find("going to have the normal amount") != -1:
			_arm( func(): _drop_beat("jug", true))
		elif t.find("thank you!") != -1:
			_arm(_beat_drink)
		elif t.find("bleh-") != -1:
			set_idimya_pose("bleh")
			play_coffee_bleh_effect()
		elif t.find("ah yes delicious") != -1:
			set_idimya_pose("idle")
		elif t.find("feels like i'm melting") != -1:
			set_idimya_pose("trans1")
		elif t.find("whoopsie") != -1:
			set_idimya_pose("idle")
		elif t.find("delicious snack") != -1:
			set_idimya_pose("happy")
		_apply_sheet_override()





	if speaker == "idimya" and not _suppress_line_pulse:
		if not (_current_pose == "trans1" and pose_before == "trans1"):
			_pulse_squash(_current_pose)




func _apply_sheet_override() -> void :
	if _beat_running or _prey_started:
		return
	var m: Variant = _expr_map.get(DialogueManager.current_id)
	if typeof(m) != TYPE_DICTIONARY:
		return
	var e: Variant = m.get(str(DialogueManager._line_index + 1))
	if e != null and str(e) != "":
		set_idimya_pose(str(e))


func _load_expressions() -> void :
	var f: = FileAccess.open(EXPRESSIONS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_expr_map = parsed


func _sheet_expression(node: String, line0: int) -> String:
	var m: Variant = _expr_map.get(node)
	if typeof(m) == TYPE_DICTIONARY:
		var e: Variant = m.get(str(line0 + 1))
		if e != null:
			return String(e)
	return "idle"




func _apply_sheet_pose() -> void :
	if _beat_running or _prey_started:
		return
	var node: = DialogueManager.current_id
	if node == "intro" or node == "0":
		return
	set_idimya_pose(_sheet_expression(node, DialogueManager._line_index))

func _on_node_entered(node_id: String) -> void :
	if node_id == "0":
		_in_node0 = true
		set_idimya_pose("idle")
	elif node_id != "intro" and not _in_node0:
		set_idimya_pose("idle")

func _on_choices_shown(_choices: Array) -> void :
	_opening_active = false







func _def_pivot() -> Vector2:
	return Vector2(ART_W * 0.5, ART_H)




func _pulse_squash(pose: String, force: bool = false, dur_scale: float = 1.0, no_settle: bool = false) -> void :
	if not idle_enabled:
		return
	if not force and (_beat_running or _prey_started):
		return
	_deform_amp = _DEF_BIGGER if pose in _SQUASH_BIGGER_POSES else _DEF_BIG
	_deform_dur_scale = maxf(dur_scale, 0.01)
	_deform_no_settle = no_settle
	_deform_active = true
	_deform_t = 0.0




func _reset_life() -> void :
	_deform_active = false
	_deform_t = 0.0
	_deform_amp = 1.0
	_deform_dur_scale = 1.0
	_deform_no_settle = false
	idimya.scale = Vector2.ONE
	idimya.position = _base_pos



func _deform_scale() -> Vector2:
	if not _deform_active:
		return Vector2.ONE
	var mid: = _DEF_MID * _deform_dur_scale
	var out: = _DEF_OUT * _deform_dur_scale
	var dur: = _DEF_DUR * _deform_dur_scale
	var t: = _deform_t
	var squash: = Vector2.ONE + _DEF_SQUASH_D * _deform_amp
	var over: = Vector2.ONE + _DEF_OVERSHOOT_D * _deform_amp
	if t < mid:
		return Vector2.ONE.lerp(squash, _smooth(t / mid))
	elif t < out:
		return squash.lerp(over, _smooth((t - mid) / (out - mid)))
	elif _deform_no_settle:
		return over
	elif t >= dur:
		_deform_active = false
		return Vector2.ONE
	else:
		return over.lerp(Vector2.ONE, _smooth((t - out) / (dur - out)))




func _to_local(px_1440: float) -> float:
	var vh: = float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	var k: = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)) / ART_W
	return px_1440 * (vh / 1440.0) / maxf(k, 0.0001)




func _idle_offset() -> Vector2:
	var a: = 0.5 - 0.5 * cos(_idle_t * TAU / maxf(idle_vert_period_a, 0.1))
	var b: = 0.5 - 0.5 * cos(_idle_t * TAU / maxf(idle_vert_period_b, 0.1) + 1.7)
	var down: = (0.7 * a + 0.3 * b) * _to_local(idle_vert_amp)
	var side: = sin(_idle_t * TAU / maxf(idle_horz_period, 0.1)) * _to_local(idle_horz_amp)
	return Vector2(side, down)

func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)





func _update_idimya_life(delta: float) -> void :
	if not idle_enabled:
		return
	_idle_t += delta
	if _deform_active:
		_deform_t += delta
	var ds: = _deform_scale()
	var off: = _idle_offset()
	var pivot: = _def_pivot()


	idimya.scale = ds
	idimya.position = _base_pos + Vector2(pivot.x * (1.0 - ds.x), pivot.y * (1.0 - ds.y)) + off




func _process(delta: float) -> void :
	_update_idimya_life(delta)
	if not candle_glow_enabled or not candle_glow.visible:
		return
	_flicker_t += delta

	var n: = sin(_flicker_t * 3.1) * 0.6 + sin(_flicker_t * 7.7 + 1.3) * 0.4
	candle_glow.self_modulate.a = clampf(candle_glow_base_alpha + n * 0.05, 0.0, 1.0)
	candle_glow.scale = Vector2.ONE * (candle_glow_scale + n * 0.03)

func _input(event: InputEvent) -> void :
	if not debug_preview:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_idimya_pose("idle")
			KEY_2: set_idimya_pose("happy")
			KEY_3: set_idimya_pose("neutral")
			KEY_4: set_idimya_pose("drink")
			KEY_5: set_idimya_pose("bleh")
			KEY_6: set_idimya_pose("trans1")
			KEY_7: set_idimya_pose("trans2")
			KEY_8: set_idimya_pose("trans3")
			KEY_9: set_idimya_pose("trans4")
			KEY_Q: waiter.visible = not waiter.visible
			KEY_W: cup.visible = not cup.visible
			KEY_E: jug.visible = not jug.visible
			KEY_R: play_coffee_bleh_effect()
			KEY_T: set_idimya_pose("neutral");play_transformation()
			KEY_Y: _beat_drink()
			KEY_U: set_idimya_pose("trans1")
