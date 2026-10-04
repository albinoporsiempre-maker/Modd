extends Node2D














@export_group("Pan")

@export var pan_duration: float = 4.0

@export var background_pan_amount: float = 0.0


@export var arrival_hold: float = 2.0

@export var settle_hold: float = 1.0

@export_group("Parallax (nearer = larger)")
@export var fg1_parallax_multiplier: float = 1.15
@export var fg2_parallax_multiplier: float = 1.3
@export var fg3_parallax_multiplier: float = 1.15









@export_range(0.0, 1.0) var fg1_anchor: float = 0.0
@export_range(0.0, 1.0) var fg2_anchor: float = 0.5
@export_range(0.0, 1.0) var fg3_anchor: float = 1.0

@export_group("Trigger / Debug")

@export var pan_trigger_line: String = "or not even that"


@export var debug_autoplay: bool = false

const ART_W: = 5760.0
const ART_H: = 2160.0

@onready var background: Sprite2D = $Background
@onready var fg1: Sprite2D = $FG1
@onready var fg2: Sprite2D = $FG2
@onready var fg3: Sprite2D = $FG3

var _start_x: float = 0.0
var _amount: float = 0.0
var _panned: bool = false
var _pan_tween: Tween

var _pan_pending: bool = false

func _ready() -> void :
	_layout()
	if not debug_autoplay:
		DialogueManager.line_shown.connect(_on_line_shown)


		var ui: = get_tree().get_first_node_in_group("dialogue_box")
		if ui and ui.has_signal("user_advanced"):
			ui.user_advanced.connect(_on_user_advanced)
		Sfx.play_ambience("longshot_ambience", 1.5)
		_arrival_hold()
	else:
		call_deferred("start_pan")

func _on_user_advanced() -> void :
	if _pan_pending and not _panned:
		_pan_pending = false
		start_pan()




func _arrival_hold() -> void :
	_set_dialogue_visible(false)
	DialogueManager.set_advance_locked(true)
	await get_tree().create_timer(arrival_hold).timeout
	if not _panned:
		_set_dialogue_visible(true)
		DialogueManager.set_advance_locked(false)


func _set_dialogue_visible(v: bool) -> void :
	if debug_autoplay:
		return
	var ui: = get_tree().get_first_node_in_group("dialogue_box")
	if ui:
		ui.visible = v

func _layout() -> void :
	var vp: = _viewport_size()
	var k: = vp.y / ART_H
	var art_gw: = ART_W * k
	var full_travel: = art_gw - vp.x
	_amount = background_pan_amount if background_pan_amount > 0.0 else full_travel
	_start_x = - full_travel
	for s in [background, fg1, fg2, fg3]:
		s.centered = false
		s.scale = Vector2(k, k)
	_apply_pan(1.0 if _panned else 0.0)

func _viewport_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)), 
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))


func _apply_pan(p: float) -> void :
	background.position = Vector2(_bg_x(p), 0.0)
	fg1.position = Vector2(_fg_x(p, fg1_parallax_multiplier, fg1_anchor), 0.0)
	fg2.position = Vector2(_fg_x(p, fg2_parallax_multiplier, fg2_anchor), 0.0)
	fg3.position = Vector2(_fg_x(p, fg3_parallax_multiplier, fg3_anchor), 0.0)

func _bg_x(p: float) -> float:
	return _start_x + p * _amount



func _fg_x(p: float, mult: float, anchor: float) -> float:
	return _bg_x(p) + _amount * (mult - 1.0) * (p - anchor)

func _on_line_shown(_speaker: String, text: String, _is_last: bool) -> void :
	if _panned:
		return
	if text.to_lower().find(pan_trigger_line.to_lower()) != -1:

		_pan_pending = true
		DialogueManager.set_advance_locked(true)

func start_pan() -> void :
	if _panned:
		return
	_panned = true
	if not debug_autoplay:
		DialogueManager.set_advance_locked(true)
		_set_dialogue_visible(false)
	if _pan_tween:
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.tween_method(_apply_pan, 0.0, 1.0, pan_duration)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.finished.connect(_on_pan_done, CONNECT_ONE_SHOT)

func _on_pan_done() -> void :
	if debug_autoplay:
		return
	await get_tree().create_timer(settle_hold).timeout
	_set_dialogue_visible(true)
	DialogueManager.set_advance_locked(false)
	DialogueManager.advance()


func replay() -> void :
	if _pan_tween:
		_pan_tween.kill()
	_panned = false
	_apply_pan(0.0)
	start_pan()

func _input(event: InputEvent) -> void :
	if debug_autoplay and event is InputEventKey and event.pressed and not event.echo\
	and event.keycode == KEY_R:
		replay()

func _exit_tree() -> void :

	if not debug_autoplay:
		DialogueManager.set_advance_locked(false)
		_set_dialogue_visible(true)

		Sfx.stop_ambience(1.2)
