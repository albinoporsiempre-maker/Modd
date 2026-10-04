extends Control




signal dismissed

@onready var label: Label = %Time
@onready var arrow: Label = %Arrow

var _plain: = ""
var _typing: = false
var _revealed: = 0
var _total: = 0
var _progress: = 0.0
var _done: = false
var _arrow_tween: Tween
var _rest_y: = 0.0
var _rest_set: = false

const CPS: = 15.0

func _ready() -> void :
	visible = false
	UIStyle.label_body(label, UIStyle.SIZE_DIALOGUE, UIStyle.TEXT_PRIMARY)
	UIStyle.label_body(arrow, 20, UIStyle.TEXT_SECONDARY)
	arrow.visible = false

func play_and_wait(text: String) -> void :
	_play(text)
	await dismissed
	visible = false

func _play(text: String) -> void :
	visible = true
	_plain = text
	label.text = text
	_total = text.length()
	_revealed = 0
	_progress = 0.0
	_typing = _total > 0
	_done = false
	label.visible_characters = 0
	_stop_arrow()
	arrow.visible = false

func _char_cost(i: int) -> float:
	if i >= 0 and i < _plain.length():
		var ch: = _plain[i]
		if ch == "." or ch == "…":
			return UIStyle.TYPE_DOT_MULT
		if ch == "," or ch == "!" or ch == "?" or ch == ";" or ch == ":" or ch == "-":
			return UIStyle.TYPE_PUNCT_MULT
	return 1.0

func _process(delta: float) -> void :
	if _typing:
		_progress += delta * CPS
		while _revealed < _total and _progress >= _char_cost(_revealed):
			_progress -= _char_cost(_revealed)
			_revealed += 1
		label.visible_characters = _revealed
		if _revealed >= _total:
			_typing = false
			_done = true
			_start_arrow()

func _complete() -> void :
	_typing = false
	_revealed = _total
	label.visible_characters = -1
	_done = true
	_start_arrow()

func _confirm() -> void :
	if _typing:
		_complete()
	elif _done:
		_stop_arrow()
		dismissed.emit()

func _gui_input(event: InputEvent) -> void :
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_confirm()

func _input(event: InputEvent) -> void :
	if visible and event is InputEventKey and event.pressed and not event.echo\
	and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_KP_ENTER):
		_confirm()

func _start_arrow() -> void :
	arrow.visible = true
	_stop_arrow()
	if not _rest_set:
		_rest_y = arrow.position.y
		_rest_set = true
	arrow.position.y = _rest_y
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(arrow, "position:y", _rest_y - 6.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(arrow, "position:y", _rest_y, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_arrow() -> void :
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()
	if _rest_set:
		arrow.position.y = _rest_y
