extends MarginContainer
class_name ChoiceRow






const BOX: = UIStyle.BOX_SIZE
const BOX_STROKE: = UIStyle.BOX_STROKE
const X_STROKE: = UIStyle.X_STROKE
const GAP: = UIStyle.BOX_GAP
const TOP_PAD: = 6.0
const DIM_ALPHA: = 0.5

var child_id: String = ""
var _label: String = ""
var _marked: bool = false
var rtl: RichTextLabel




var _hold_mode: bool = false
var _hold_progress: float = 0.0
var _retract_tween: Tween

func setup(_number: int, label: String, id: String) -> void :
	child_id = id
	_label = label
	if rtl:
		_refresh_text()

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("margin_left", int(BOX + GAP))
	add_theme_constant_override("margin_top", int(TOP_PAD))
	add_theme_constant_override("margin_bottom", int(TOP_PAD))
	rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.rich_body(rtl, UIStyle.SIZE_CHOICE, UIStyle.TEXT_PRIMARY)
	add_child(rtl)


	_marked = false
	_refresh_text()
	modulate = Color(1, 1, 1, DIM_ALPHA)

func _refresh_text() -> void :
	if not rtl:
		return
	if _marked:

		rtl.text = "[shake rate=15.0 level=4 connected=1]%s[/shake]" % _label
	else:
		rtl.text = _label

func set_marked(v: bool) -> void :
	if _marked == v and rtl:
		return
	_marked = v
	_refresh_text()
	modulate = Color(1, 1, 1, 1.0 if v else DIM_ALPHA)
	queue_redraw()



func set_hold_mode(v: bool) -> void :
	_hold_mode = v



func set_hold_progress(p: float) -> void :
	if _retract_tween and _retract_tween.is_valid():
		_retract_tween.kill()
	_hold_progress = clampf(p, 0.0, 1.0)
	queue_redraw()



func retract(dur: float = 0.15) -> void :
	if _retract_tween and _retract_tween.is_valid():
		_retract_tween.kill()
	if _hold_progress <= 0.0:
		return
	_retract_tween = create_tween()
	_retract_tween.tween_method(_set_hold_p, _hold_progress, 0.0, dur)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_hold_p(v: float) -> void :
	_hold_progress = v
	queue_redraw()

func _draw() -> void :
	var box_y: = TOP_PAD + (float(UIStyle.SIZE_CHOICE) - BOX) * 0.5
	var r: = Rect2(Vector2(0.0, box_y), Vector2(BOX, BOX))
	draw_rect(r, UIStyle.RULE, false, BOX_STROKE)


	var p: float = _hold_progress if _hold_mode else (1.0 if _marked else 0.0)
	if p <= 0.0:
		return



	var inset: = BOX_STROKE
	var a1: = Vector2(r.position.x + inset, r.position.y + inset)
	var b1: = Vector2(r.position.x + r.size.x - inset, r.position.y + r.size.y - inset)
	var a2: = Vector2(r.position.x + r.size.x - inset, r.position.y + inset)
	var b2: = Vector2(r.position.x + inset, r.position.y + r.size.y - inset)
	var m: = (a1 + b1) * 0.5
	draw_line(m.lerp(a1, p), m.lerp(b1, p), UIStyle.X_COLOR, X_STROKE)
	draw_line(m.lerp(a2, p), m.lerp(b2, p), UIStyle.X_COLOR, X_STROKE)
