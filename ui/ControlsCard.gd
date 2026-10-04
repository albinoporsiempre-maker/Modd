extends CanvasLayer








signal dismissed


const ROWS: = [
	["ENTER / SPACE / LMB", "progress dialogue"], 
	["ARROW KEYS / SCROLL WHEEL", "navigate choices"], 
	["HOLD ENTER / SPACE / LMB", "confirm choice"], 
	["HOLD ENTER / SPACE / LMB FOR 3 SECONDS", "fast-forward dialogue"], 
	["SCROLL WHEEL", "review recent dialogue"], 
	["TAB", "options"], 
]

const CLINICAL_THEME: = preload("res://ui/clinical.tres")

var _button: Button

func _ready() -> void :
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void :
	var root: = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg: = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center: = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	for r in ROWS:

		var entry: = VBoxContainer.new()
		entry.add_theme_constant_override("separation", 1)
		var key: = Label.new()
		UIStyle.label_bold(key, 18, UIStyle.TEXT_PRIMARY)
		key.text = str(r[0])
		entry.add_child(key)
		var desc: = Label.new()
		UIStyle.label_body(desc, 18, UIStyle.TEXT_SECONDARY)
		desc.text = str(r[1])
		desc.clip_text = false
		entry.add_child(desc)
		box.add_child(entry)



	_button = Button.new()
	_button.text = "Got it"
	_button.theme = CLINICAL_THEME
	_button.add_theme_font_override("font", UIStyle.font_body())
	_button.custom_minimum_size = Vector2(130, 44)
	_button.anchor_left = 1.0
	_button.anchor_top = 1.0
	_button.anchor_right = 1.0
	_button.anchor_bottom = 1.0
	_button.offset_left = -190.0
	_button.offset_top = -88.0
	_button.offset_right = -60.0
	_button.offset_bottom = -44.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_button.pressed.connect(_on_got_it)
	root.add_child(_button)


func play_and_wait() -> void :
	visible = true
	_button.grab_focus()
	await dismissed
	visible = false

func _on_got_it() -> void :
	dismissed.emit()
