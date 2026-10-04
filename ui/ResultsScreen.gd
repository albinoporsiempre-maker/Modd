extends Control







signal restart_requested

const ValuesCompassScript: = preload("res://ui/ValuesCompass.gd")

@onready var page1: Control = %Page1
@onready var page2: Control = %Page2
@onready var next_button: Button = %NextButton
@onready var back_button: Button = %BackButton
@onready var new_run_button: Button = %NewRunButton
@onready var quit_button: Button = %QuitButton

@onready var compass: Control = %Compass
@onready var legend_idimya_dot: Panel = %LegendIdimyaDot
@onready var legend_you_dot: Panel = %LegendYouDot
@onready var attitude_value: Label = %AttitudeValue
@onready var a_heading: RichTextLabel = %ABehaviorHeading
@onready var a_prose: RichTextLabel = %AProse
@onready var verdict_value: Label = %Verdict
@onready var crush_line: RichTextLabel = %CrushLine
@onready var _card: PanelContainer = $Outer / Card
@onready var _dim: ColorRect = $Dim
@onready var _log: VBoxContainer = %Log
@onready var _attitude_label: Label = $Outer / Card / Pad / Pages / Page1 / V1 / AttitudeLabel
@onready var _verdict_label: Label = %VerdictLabel
@onready var _space_before_a: Control = %SpaceBeforeA
@onready var _legend_l1: Label = $Outer / Card / Pad / Pages / Page1 / V1 / Legend / IdimyaItem / L1
@onready var _legend_l2: Label = $Outer / Card / Pad / Pages / Page1 / V1 / Legend / YouItem / L2
@onready var _cg: TextureRect = $CG
@onready var _nav2: Control = $Outer / Card / Pad / Pages / Page2 / Nav2


const CG_HOLD: = 3.0

var _typed_once: bool = false
var _para_nodes: Array = []
var _extra_paras: Array = []
var _revealing: bool = false
var _skip: bool = false
var _show_crush: bool = false



static func a_category(a: int) -> String:
	if a <= 0:
		return "ASSERTIVE"
	elif a <= 3:
		return "NEUTRAL"
	return "AGREEABLE"



const A_BODY: = {
	"ASSERTIVE": "You did not fold under pressure.\nNot a simp!", 
	"NEUTRAL": "You held your poise, finding common ground with Idimya while maintaining a fair share of differences.", 
	"AGREEABLE": "But do you genuinely stand behind all those rhetorical claims? Or were you just saying whatever it took not to get eaten? Perhaps you were simply trying to lie your way into a girl's pants.\n\nHow long would this peace last?\n\nYou couldn't help but wonder.", 
}
const CRUSH_TEXT: = "...while lowkey having a crush on you."
const VERDICT_LEAD: = "IDIMYA SEES YOU AS HER"

func _ready() -> void :
	visible = false
	next_button.pressed.connect(_go_page2)
	back_button.pressed.connect(_show_page1)
	new_run_button.pressed.connect( func(): restart_requested.emit())
	quit_button.pressed.connect( func(): get_tree().quit())
	if OS.has_feature("web"):
		quit_button.visible = false
	_style_dot(legend_idimya_dot, ValuesCompassScript.COLOR_IDIMYA)
	_style_dot(legend_you_dot, ValuesCompassScript.COLOR_YOU)
	_apply_style()



func _apply_style() -> void :

	_dim.color = Color(0, 0, 0, 1)
	_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	UIStyle.label_bold(_attitude_label, UIStyle.SIZE_SUBLABEL, UIStyle.TEXT_SECONDARY)
	UIStyle.label_bold(attitude_value, UIStyle.SIZE_CLASS, UIStyle.TEXT_PRIMARY)
	UIStyle.label_body(_legend_l1, UIStyle.SIZE_SUBLABEL, UIStyle.TEXT_SECONDARY)
	UIStyle.label_body(_legend_l2, UIStyle.SIZE_SUBLABEL, UIStyle.TEXT_SECONDARY)

	UIStyle.label_bold(_verdict_label, UIStyle.SIZE_SUBLABEL, UIStyle.TEXT_SECONDARY)
	UIStyle.label_bold(verdict_value, UIStyle.SIZE_VERDICT, UIStyle.VERDICT_COLOR)
	UIStyle.rich_body(crush_line, UIStyle.SIZE_PROSE, UIStyle.TEXT_SECONDARY)
	UIStyle.rich_body(a_heading, UIStyle.SIZE_SUBLABEL, UIStyle.TEXT_SECONDARY)
	UIStyle.rich_body(a_prose, UIStyle.SIZE_PROSE, UIStyle.TEXT_PRIMARY)

	a_heading.add_theme_font_override("normal_font", UIStyle.font_bold())


	for n in [_verdict_label, verdict_value, a_heading, a_prose, crush_line]:
		UIStyle.shadow(n)

	for b in [next_button, back_button, new_run_button, quit_button]:
		b.add_theme_font_override("font", UIStyle.font_body())


func _style_dot(p: Panel, col: Color) -> void :
	var sb: = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(7)
	p.add_theme_stylebox_override("panel", sb)


func show_results(outcome: Dictionary, cras: Dictionary) -> void :
	compass.set_player(float(cras.get("C", 0)), float(cras.get("R", 0)))
	attitude_value.text = str(outcome.get("compass", "?"))

	var cat: = a_category(int(cras.get("A", 0)))


	_verdict_label.set_meta("raw", VERDICT_LEAD)
	a_heading.set_meta("raw", "YOU ARE %s WITH IDIMYA." % cat)
	a_heading.text = ""



	_clear_extra_paras()
	var paras: = _format_prose(A_BODY.get(cat, "")).split("\n\n", false)
	_para_nodes = [a_prose]
	a_prose.set_meta("raw", paras[0] if paras.size() > 0 else "")
	a_prose.text = ""
	for i in range(1, paras.size()):
		var p: = _make_para(paras[i])
		_log.add_child(p)
		_extra_paras.append(p)
		_para_nodes.append(p)


	var verdict: = str(outcome.get("verdict", "?"))
	verdict_value.set_meta("raw", verdict)
	verdict_value.text = ""
	var crush: = bool(outcome.get("secret_crush", false))
	_show_crush = crush
	crush_line.set_meta("raw", CRUSH_TEXT)
	crush_line.text = ""
	crush_line.visible = crush


	_cg.texture = _load_cg(verdict, crush)
	_cg.visible = false

	_typed_once = false
	_show_page1()
	visible = true



func _load_cg(verdict: String, crush: bool) -> Texture2D:
	var key: = verdict.strip_edges().to_lower()
	if key != "ally" and key != "rival":
		return null
	var path: = "res://assets/ending/%s%s.jpeg" % [key, ("S" if crush else "")]
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _make_para(text: String) -> RichTextLabel:
	var r: = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(0, 24)
	UIStyle.rich_body(r, UIStyle.SIZE_PROSE, UIStyle.TEXT_PRIMARY)
	r.set_meta("raw", text)
	r.text = ""
	return r

func _clear_extra_paras() -> void :
	for p in _extra_paras:
		if is_instance_valid(p):
			p.queue_free()
	_extra_paras.clear()
	_para_nodes.clear()



func _format_prose(body: String) -> String:
	var out: PackedStringArray = []
	for para in body.split("\n\n", false):
		var flat: = " ".join(para.split("\n", false))
		var lines: PackedStringArray = []
		for s in _split_sentences(flat):
			if s != "":
				lines.append(s)
		out.append("\n".join(lines))
	return "\n\n".join(out)

func _split_sentences(text: String) -> Array:
	var sentences: Array = []
	var cur: = ""
	var i: = 0
	while i < text.length():
		var ch: = text[i]
		cur += ch
		if ch == "." or ch == "!" or ch == "?":

			while i + 1 < text.length() and (text[i + 1] == "." or text[i + 1] == "!" or text[i + 1] == "?"):
				i += 1
				cur += text[i]

			if i + 1 >= text.length() or text[i + 1] == " ":
				sentences.append(cur.strip_edges())
				cur = ""
				if i + 1 < text.length() and text[i + 1] == " ":
					i += 1
		i += 1
	if cur.strip_edges() != "":
		sentences.append(cur.strip_edges())
	return sentences

func _show_page1() -> void :
	page1.visible = true
	page2.visible = false
	_cg.visible = false
	next_button.grab_focus()

func _go_page2() -> void :
	page1.visible = false
	page2.visible = true
	_cg.visible = true
	if _typed_once:
		_nav2.visible = true
		_show_page2_full()
		new_run_button.grab_focus()
	else:
		_typed_once = true
		_reveal_page2()

func _page2_elements() -> Array:
	var seq: Array = [_verdict_label, verdict_value]
	if _show_crush:
		seq.append(crush_line)
	seq.append(_space_before_a)
	seq.append(a_heading)
	for p in _para_nodes:
		seq.append(p)
	return seq


func _show_page2_full() -> void :
	for n in _page2_elements():
		n.visible = true
		if n.has_meta("raw"):
			_set_partial(n, String(n.get_meta("raw")), n is RichTextLabel)




func _reveal_page2() -> void :
	_revealing = true
	_skip = false
	_nav2.visible = false
	for n in _page2_elements():
		n.visible = false
		if n.has_meta("raw"):
			_set_partial(n, "", n is RichTextLabel)
	await get_tree().process_frame
	await _wait_or_skip(CG_HOLD)
	await _typewriter_page2()

	_show_page2_full()
	_nav2.visible = true
	_revealing = false
	new_run_button.grab_focus()



func _typewriter_page2() -> void :
	for n in _page2_elements():
		if _skip:
			return
		n.visible = true
		if n.has_meta("raw"):
			await _type_node(n, String(n.get_meta("raw")))
		else:
			await _wait_or_skip(0.18)

		if n == verdict_value:
			await _wait_or_skip(2.0)
		elif n in _para_nodes and n != _para_nodes[_para_nodes.size() - 1]:
			await _wait_or_skip(1.0)
		else:
			await _wait_or_skip(0.12)




func _type_node(node: Control, raw: String) -> void :
	var is_rich: = node is RichTextLabel
	var total: = raw.length()
	if total == 0:
		_set_partial(node, "", is_rich)
		return
	var tw: = create_tween()
	tw.tween_method( func(k: int): _set_partial(node, raw.substr(0, k), is_rich), 0, total, maxf(0.2, float(total) / UIStyle.TYPE_CPS))
	while tw.is_valid() and tw.is_running():
		if _skip:
			tw.kill()
			_set_partial(node, raw, is_rich)
			return
		await get_tree().process_frame


func _wait_or_skip(t: float) -> void :
	var elapsed: = 0.0
	while elapsed < t and not _skip:
		await get_tree().create_timer(0.04).timeout
		elapsed += 0.04


func _input(event: InputEvent) -> void :
	if not _revealing:
		return
	var confirm: bool = event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton:
		var mb: = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			confirm = true
	if confirm:
		_skip = true
		get_viewport().set_input_as_handled()

func _set_partial(node: Control, s: String, is_rich: bool) -> void :
	if is_rich:
		if node == crush_line:

			node.text = "[center][shake rate=15.0 level=4 connected=1]%s[/shake][/center]" % s
		else:
			node.text = "[center]%s[/center]" % s
	else:
		node.text = s
