extends CanvasLayer






signal closed
signal save_requested
signal load_requested(data: Dictionary)
signal restart_requested
signal skip_intro_requested
signal quit_requested



const ChoiceRowScript: = preload("res://ui/ChoiceRow.gd")
const RouteGraphScript: = preload("res://ui/RouteGraph.gd")
const VolumeSliderScript: = preload("res://ui/VolumeSlider.gd")

const MENU_ITEMS: = [
	{"id": "resume", "label": "RESUME"}, 
	{"id": "save", "label": "SAVE"}, 
	{"id": "load", "label": "LOAD SAVE"}, 
	{"id": "restart", "label": "RESTART"}, 
	{"id": "skip", "label": "RESTART (SKIP INTRO)"}, 
	{"id": "quit", "label": "QUIT"}, 
]

var _root: Control
var _menu_page: Control
var _load_page: Control
var _menu_rows: Array = []
var _menu_focus: = -1
var _menu_catcher: Control

const WHEEL_COOLDOWN_MS: = 90
var _last_wheel_ms: = 0
func _wheel_ready() -> bool:
	var now: = Time.get_ticks_msec()
	if now - _last_wheel_ms < WHEEL_COOLDOWN_MS:
		return false
	_last_wheel_ms = now
	return true
var _toast: Label


var _music_slider: Control
var _sfx_slider: Control
var _drag_slider: Control = null
const VOL_WHEEL_STEP: = 0.05

var _load_list: VBoxContainer
var _load_scroll: ScrollContainer
var _load_strips: Array = []
var _load_focus: = -1
var _load_catcher: Control
var _load_empty: Label

var _page: = "menu"

func _ready() -> void :
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()




func open() -> void :
	visible = true


	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_menu()

func close() -> void :
	visible = false
	_drag_slider = null
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func on_saved(path: String) -> void :
	_toast.text = "checkpoint saved" if path != "" else "save failed"
	_toast.visible = true




func _build() -> void :
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim: = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_menu_page = _build_menu_page()
	_root.add_child(_menu_page)
	_load_page = _build_load_page()
	_root.add_child(_load_page)

func _heading(text: String, size: int) -> Label:
	var l: = Label.new()
	UIStyle.label_bold(l, size, UIStyle.TEXT_PRIMARY)
	l.text = text
	return l

func _build_menu_page() -> Control:
	var page: = Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)

	_menu_catcher = Control.new()
	_menu_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_catcher.gui_input.connect(_on_menu_catcher_input)
	page.add_child(_menu_catcher)

	var box: = VBoxContainer.new()
	box.position = Vector2(140, 120)
	box.add_theme_constant_override("separation", 8)
	page.add_child(box)
	box.add_child(_heading("OPTIONS", 26))
	var rule: = ColorRect.new()
	rule.color = UIStyle.RULE
	rule.custom_minimum_size = Vector2(560, 1)
	box.add_child(rule)
	var spacer: = Control.new();spacer.custom_minimum_size = Vector2(0, 8);box.add_child(spacer)

	var items: Array = MENU_ITEMS.filter( func(it): return not (it["id"] == "quit" and OS.has_feature("web")))
	for item in items:
		var row: Control = ChoiceRowScript.new()
		box.add_child(row)
		row.setup(0, item["label"], item["id"])
		_menu_rows.append(row)


	var vgap: = Control.new();vgap.custom_minimum_size = Vector2(0, 18);box.add_child(vgap)
	var vrule: = ColorRect.new();vrule.color = UIStyle.RULE
	vrule.custom_minimum_size = Vector2(560, 1);box.add_child(vrule)
	var vgap2: = Control.new();vgap2.custom_minimum_size = Vector2(0, 10);box.add_child(vgap2)
	_music_slider = _add_volume_row(box, "MUSIC VOLUME", MusicManager.get_user_volume_linear())
	_sfx_slider = _add_volume_row(box, "SFX VOLUME", Sfx.get_user_volume_linear())

	_toast = Label.new()
	UIStyle.label_body(_toast, 15, UIStyle.TEXT_SECONDARY)
	_toast.visible = false
	var tgap: = Control.new();tgap.custom_minimum_size = Vector2(0, 10);box.add_child(tgap)
	box.add_child(_toast)
	return page


func _add_volume_row(box: VBoxContainer, label_text: String, value: float) -> Control:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var lbl: = Label.new()

	UIStyle.label_body(lbl, UIStyle.SIZE_CHOICE, UIStyle.TEXT_PRIMARY)
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var slider: Control = VolumeSliderScript.new()
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	box.add_child(row)
	slider.set_value(value)
	return slider

func _build_load_page() -> Control:
	var page: = Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	_load_catcher = Control.new()
	_load_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_catcher.gui_input.connect(_on_load_catcher_input)
	page.add_child(_load_catcher)

	var head: = _heading("LOAD SAVE", 26)
	head.position = Vector2(140, 60)
	page.add_child(head)
	var hint: = Label.new()
	UIStyle.label_body(hint, 14, UIStyle.TEXT_SECONDARY)
	hint.text = "↑/↓ select save   ·   ←/→ trace route   ·   enter load   ·   esc back"
	hint.position = Vector2(140, 96)
	page.add_child(hint)

	_load_scroll = ScrollContainer.new()
	_load_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_scroll.offset_left = 100
	_load_scroll.offset_right = -100
	_load_scroll.offset_top = 130
	_load_scroll.offset_bottom = -40
	_load_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_load_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_load_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_load_scroll)
	_load_list = VBoxContainer.new()
	_load_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_list.add_theme_constant_override("separation", 18)
	_load_scroll.add_child(_load_list)

	_load_empty = Label.new()
	UIStyle.label_body(_load_empty, 16, UIStyle.TEXT_SECONDARY)
	_load_empty.text = "no saves yet."
	_load_empty.position = Vector2(140, 160)
	_load_empty.visible = false
	page.add_child(_load_empty)
	return page




func _show_menu() -> void :
	_page = "menu"
	_menu_page.visible = true
	_load_page.visible = false
	_toast.visible = false


	for row in _menu_rows:
		row.set_marked(false)
	_menu_focus = -1
	_set_menu_focus(0, false)

func _set_menu_focus(i: int, sound: bool = true) -> void :
	if _menu_rows.is_empty():
		return
	i = clampi(i, 0, _menu_rows.size() - 1)
	if i == _menu_focus:
		return
	if _menu_focus >= 0 and _menu_focus < _menu_rows.size():
		_menu_rows[_menu_focus].set_marked(false)
	_menu_focus = i
	_menu_rows[i].set_marked(true)
	if sound:
		Sfx.play("choice_navigate")



func _menu_row_at(pos: Vector2) -> int:
	for i in _menu_rows.size():
		var r: Rect2 = _menu_rows[i].get_global_rect()
		if pos.y >= r.position.y and pos.y <= r.position.y + r.size.y\
		and pos.x >= r.position.x - 10.0 and pos.x <= r.position.x + 560.0:
			return i
	return -1

func _confirm_menu() -> void :
	if _menu_focus < 0:
		return
	Sfx.play("choice_confirm")
	match _menu_rows[_menu_focus].child_id:
		"resume": closed.emit()
		"save": save_requested.emit()
		"load": _show_load()
		"restart": restart_requested.emit()
		"skip": skip_intro_requested.emit()
		"quit": quit_requested.emit()

func _on_menu_catcher_input(event: InputEvent) -> void :


	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb: = event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_confirm_menu()




func _slider_at(pos: Vector2) -> Control:
	for sl in [_music_slider, _sfx_slider]:
		if sl != null and sl.get_global_rect().has_point(pos):
			return sl
	return null



func _apply_slider(sl: Control, v: float, persist: bool) -> void :
	sl.set_value(v)
	if sl == _music_slider:
		MusicManager.set_user_volume_linear(sl.value)
	else:
		Sfx.set_user_volume_linear(sl.value)
	if persist:
		_persist_slider(sl)

func _persist_slider(sl: Control) -> void :
	MetaState.set_flag("music_volume" if sl == _music_slider else "sfx_volume", sl.value)




func _show_load() -> void :
	_page = "load"
	_menu_page.visible = false
	_load_page.visible = true
	_build_strips()

func _build_strips() -> void :
	for c in _load_list.get_children():
		c.queue_free()
	_load_strips.clear()
	_load_focus = -1
	var saves: = SaveManager.list_saves()
	_load_empty.visible = saves.is_empty()
	for s in saves:
		var strip: = _make_strip(s)
		_load_list.add_child(strip["ctrl"])
		_load_strips.append(strip)
	if not _load_strips.is_empty():
		_set_load_focus(0, false)




const STRIP_H: = 210




func _fmt_stamp(s: Dictionary) -> String:
	var unix: = int(s.get("timestamp_unix", 0))
	if unix <= 0:
		return str(s.get("timestamp_str", "?"))
	var tz: Dictionary = Time.get_time_zone_from_system()
	var local: = unix + int(tz.get("bias", 0)) * 60
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(local)
	return "%02d/%02d/%02d %02d:%02d:%02d" % [
		int(t.get("day", 1)), int(t.get("month", 1)), int(t.get("year", 2000)) % 100, 
		int(t.get("hour", 0)), int(t.get("minute", 0)), int(t.get("second", 0))]

func _make_strip(s: Dictionary) -> Dictionary:
	var outer: = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 4)
	outer.modulate = Color(1, 1, 1, 0.45)
	var header: = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts: = Label.new()
	UIStyle.label_body(ts, 15, UIStyle.TEXT_PRIMARY)
	ts.text = _fmt_stamp(s)
	ts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(ts)
	var pt: = Label.new()
	UIStyle.label_body(pt, 16, UIStyle.TEXT_SECONDARY)
	pt.text = SaveManager.format_playtime(float(s.get("playtime_seconds", 0.0)))
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(pt)
	outer.add_child(header)
	var rule: = ColorRect.new()
	rule.color = UIStyle.RULE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rule)
	var graph: Control = RouteGraphScript.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(0, STRIP_H)
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(graph)
	graph.set_route((s.get("data", {}) as Dictionary).get("path_history", []))
	return {"ctrl": outer, "data": s["data"], "graph": graph}

func _set_load_focus(i: int, sound: bool = true) -> void :
	if _load_strips.is_empty():
		return
	i = clampi(i, 0, _load_strips.size() - 1)
	if i == _load_focus:
		return
	if _load_focus >= 0 and _load_focus < _load_strips.size():
		_load_strips[_load_focus]["ctrl"].modulate = Color(1, 1, 1, 0.45)
		_load_strips[_load_focus]["graph"].set_focused(false)
	_load_focus = i
	_load_strips[i]["ctrl"].modulate = Color(1, 1, 1, 1.0)
	_load_strips[i]["graph"].set_focused(true)
	_load_scroll.ensure_control_visible(_load_strips[i]["ctrl"])
	if sound:
		Sfx.play("choice_navigate")



func _inspect_route(dir: int) -> void :
	if _load_focus < 0 or _load_focus >= _load_strips.size():
		return
	if _load_strips[_load_focus]["graph"].move_selection(dir):
		Sfx.play("choice_navigate")

func _confirm_load() -> void :
	if _load_focus < 0 or _load_focus >= _load_strips.size():
		return
	Sfx.play("choice_confirm")
	load_requested.emit(_load_strips[_load_focus]["data"])

func _on_load_catcher_input(event: InputEvent) -> void :


	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb: = event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_confirm_load()




func _input(event: InputEvent) -> void :
	if not visible:
		return



	if _page == "menu":
		if event is InputEventMouseMotion:
			if _drag_slider != null:
				_apply_slider(_drag_slider, _drag_slider.value_from_global_x(_root.get_global_mouse_position().x), false)
				get_viewport().set_input_as_handled()
				return

			var ri: = _menu_row_at(_root.get_global_mouse_position())
			if ri != -1:
				_set_menu_focus(ri)
			return
		if event is InputEventMouseButton:
			var vb: = event as InputEventMouseButton
			var mpos: = _root.get_global_mouse_position()
			if vb.button_index == MOUSE_BUTTON_LEFT:
				if vb.pressed:
					var sl: = _slider_at(mpos)
					if sl != null:
						_drag_slider = sl
						_apply_slider(sl, sl.value_from_global_x(mpos.x), false)
						get_viewport().set_input_as_handled()
						return
				elif _drag_slider != null:
					_persist_slider(_drag_slider)
					_drag_slider = null
					get_viewport().set_input_as_handled()
					return
			elif vb.pressed and (vb.button_index == MOUSE_BUTTON_WHEEL_UP or vb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				var sl2: = _slider_at(mpos)
				if sl2 != null:
					var d: = VOL_WHEEL_STEP if vb.button_index == MOUSE_BUTTON_WHEEL_UP else - VOL_WHEEL_STEP
					_apply_slider(sl2, sl2.value + d, true)
					get_viewport().set_input_as_handled()
					return




	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: = event as InputEventMouseButton
		var step: = 0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP: step = -1
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN: step = 1
		if step != 0:
			if _wheel_ready():
				if _page == "menu": _set_menu_focus(_menu_focus + step)
				elif _page == "load": _set_load_focus(_load_focus + step)
			get_viewport().set_input_as_handled()
			return



		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _page == "menu": _confirm_menu()
			elif _page == "load": _confirm_load()
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var handled: = true
	if event.keycode == KEY_TAB:
		if _page == "load": _show_menu()
		else: closed.emit()
	elif event.keycode == KEY_ESCAPE:
		if _page == "load": _show_menu()
		else: closed.emit()
	elif _page == "menu":
		if event.is_action("ui_up"): _set_menu_focus(_menu_focus - 1)
		elif event.is_action("ui_down"): _set_menu_focus(_menu_focus + 1)
		elif event.is_action("ui_accept"): _confirm_menu()
		else: handled = false
	elif _page == "load":
		if event.is_action("ui_up"): _set_load_focus(_load_focus - 1)
		elif event.is_action("ui_down"): _set_load_focus(_load_focus + 1)
		elif event.is_action("ui_left"): _inspect_route(-1)
		elif event.is_action("ui_right"): _inspect_route(1)
		elif event.is_action("ui_accept"): _confirm_load()
		else: handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
