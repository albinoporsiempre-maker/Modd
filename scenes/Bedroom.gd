extends Control
















@export_group("Idle motion")


@export var idle_vertical_amount: float = 6.5


@export var idle_horizontal_amount: float = 3.5


@export var idle_duration: float = 4.0

@export_group("Phone screen")

@export var transition_duration: float = 0.45






@export var page_content_frac: float = 615.0 / 3840.0

@export_group("Scripted transition")


@export var slide_at_line: String = "Oh god."
@export var slide_to_page: String = "chat"

@export_group("Debug")


@export var demo_autoplay: bool = false

const PRESENTATION_HEIGHT: = 1440.0

@onready var phone_rig: Control = %PhoneRig
@onready var screen_clip: Control = %ScreenClip
@onready var screen_content: Control = %ScreenContent

var _rig_base: Vector2 = Vector2.ZERO
var _idle_tween: Tween
var _idle_tween_h: Tween
var _page_tween: Tween
var _current_page: Control = null
var _slide_done: bool = false

func _ready() -> void :
	_rig_base = phone_rig.position
	phone_rig.resized.connect(_align_screen)

	if not Engine.is_editor_hint() and DialogueManager:
		DialogueManager.line_shown.connect(_on_line_shown)
	await get_tree().process_frame
	_align_screen()
	_init_pages()
	_start_idle()
	if demo_autoplay:
		_run_demo()

func _on_line_shown(_speaker: String, text: String, _is_last: bool) -> void :
	if _slide_done:
		return
	if text.strip_edges() == slide_at_line.strip_edges():
		_slide_done = true
		transition_to_page(slide_to_page, "slide")





func _align_screen() -> void :
	screen_content.size = phone_rig.size
	screen_content.position = - screen_clip.position


func _init_pages() -> void :
	_current_page = null
	for c in screen_content.get_children():
		if c is Control:
			(c as Control).position = Vector2.ZERO
			(c as Control).modulate.a = 1.0
			(c as Control).visible = false
	if screen_content.get_child_count() > 0:
		_current_page = screen_content.get_child(0)
		_current_page.visible = true



func transition_to_page(page_name: String, mode: String = "fade") -> void :
	var next: = screen_content.get_node_or_null(NodePath(page_name)) as Control
	if next == null:
		push_warning("Bedroom: no phone page named '%s'" % page_name)
		return
	if next == _current_page:
		return
	if _page_tween:
		_page_tween.kill()
	var cur: = _current_page



	var w: = page_content_frac * screen_content.size.x
	next.visible = true
	_page_tween = create_tween().set_parallel(true)
	if mode == "slide":
		next.position = Vector2(w, 0.0)
		next.modulate.a = 1.0
		_page_tween.tween_property(next, "position:x", 0.0, transition_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if cur:
			_page_tween.tween_property(cur, "position:x", - w, transition_duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		next.position = Vector2.ZERO
		next.modulate.a = 0.0
		_page_tween.tween_property(next, "modulate:a", 1.0, transition_duration)
		if cur:
			_page_tween.tween_property(cur, "modulate:a", 0.0, transition_duration)
	_current_page = next
	if cur:
		_page_tween.finished.connect( func():
			cur.visible = false
			cur.position = Vector2.ZERO
			cur.modulate.a = 1.0, CONNECT_ONE_SHOT)


func _to_canvas(amount_1440: float) -> float:
	var base_h: = float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	return amount_1440 * (base_h / PRESENTATION_HEIGHT)

func _start_idle() -> void :
	if _idle_tween:
		_idle_tween.kill()
	if _idle_tween_h:
		_idle_tween_h.kill()
	var vy: = _to_canvas(idle_vertical_amount)
	var hx: = _to_canvas(idle_horizontal_amount)




	phone_rig.position = _rig_base
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(phone_rig, "position:y", _rig_base.y + vy, idle_duration * 0.5)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(phone_rig, "position:y", _rig_base.y, idle_duration * 0.5)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var hdur: = idle_duration * 1.3
	_idle_tween_h = create_tween().set_loops()
	_idle_tween_h.tween_property(phone_rig, "position:x", _rig_base.x - hx, hdur * 0.5)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween_h.tween_property(phone_rig, "position:x", _rig_base.x, hdur * 0.5)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _run_demo() -> void :
	await get_tree().create_timer(1.5).timeout
	transition_to_page("chat", "fade")
