extends Control




const OutcomeCalculator: = preload("res://scripts/OutcomeCalculator.gd")

@onready var stage: Control = %Stage
@onready var end_panel: PanelContainer = %EndPanel
@onready var end_title: Label = %EndTitle
@onready var end_body: RichTextLabel = %EndBody
@onready var restart_button: Button = %RestartButton
@onready var results_screen: Control = %ResultsScreen
@onready var time_card: Control = %TimeCard


const TIME_CARD_LINE: = "not the worst way to go"
var _time_card_pending: bool = false



const BLUR_SHADER: = preload("res://shaders/blur.gdshader")
const GLASSES_NODE: = "3.3.1"
const GLASSES_LINE_INDEX: = 7
const OPEN_CUTOFF: = 20500.0
@export_group("Glasses blur")
@export var stage_blur_amount: float = 3.0
@export var front_blur_amount: float = 1.0
@export var blur_fade: float = 0.5
@export var muffle_cutoff: float = 900.0
var _stage_blur: ColorRect
var _front_blur: ColorRect
var _stage_bbc: BackBufferCopy
var _front_bbc: BackBufferCopy
var _lowpass: AudioEffectLowPassFilter
var _glasses_on: bool = false
var _blur_tween: Tween

const LOCATION_SCENES: = {
	"bedroom": "res://scenes/Bedroom.tscn", 
	"cafe": "res://scenes/MainDate.tscn", 




	"ending": "res://scenes/MainDate.tscn", 
}





const LINE_STAGE: = [
	{"needle": "this is the location she sent me alright", "scene": "res://scenes/BistroLongshot.tscn"}, 
	{"needle": "you are actually here", "scene": "res://scenes/MainDate.tscn"}, 
]

var _current_stage_path: String = ""
var _stage_instance: Node = null

func _ready() -> void :




	if OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	DialogueManager.location_changed.connect(_on_location_changed)
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.run_ended.connect(_on_run_ended)
	restart_button.pressed.connect(_restart)
	results_screen.restart_requested.connect(_restart)

	var ui: = get_tree().get_first_node_in_group("dialogue_box")
	if ui and ui.has_signal("user_advanced"):
		ui.user_advanced.connect(_on_user_advanced)
	_style_end_panel()
	_setup_glasses_blur()
	_setup_debug()
	_setup_hint()
	end_panel.visible = false
	results_screen.visible = false
	SaveManager.reset_playtime()



	await _show_controls_card()
	MusicManager.begin()
	DialogueManager.start_new_run()





const ControlsCardScript: = preload("res://ui/ControlsCard.gd")
func _show_controls_card() -> void :
	DialogueManager.set_advance_locked(true)
	var ui: = get_tree().get_first_node_in_group("dialogue_box")
	if ui:
		ui.visible = false
	var card: CanvasLayer = ControlsCardScript.new()
	add_child(card)
	await card.play_and_wait()
	card.queue_free()
	if ui:
		ui.visible = true
	DialogueManager.set_advance_locked(false)




const DEBUG_MENU_SCENE: = preload("res://ui/DebugMenu.tscn")
var _debug: CanvasLayer
var _debug_open: bool = false
var _hint: Label

func _setup_debug() -> void :
	_debug = DEBUG_MENU_SCENE.instantiate()
	add_child(_debug)
	_debug.closed.connect(_close_debug)
	_debug.save_requested.connect( func(): _debug.on_saved(save_run()))
	_debug.load_requested.connect( func(d): _close_debug();load_snapshot(d))
	_debug.restart_requested.connect( func(): _close_debug();new_run())
	_debug.skip_intro_requested.connect( func(): _close_debug();new_run_skip_intro())
	_debug.quit_requested.connect( func(): get_tree().quit())


func _setup_hint() -> void :
	var cl: = CanvasLayer.new()
	cl.layer = 35
	add_child(cl)
	_hint = Label.new()
	_hint.text = "press TAB for options"
	_hint.add_theme_font_override("font", UIStyle.font_body())
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 0.25))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -24.0
	_hint.offset_bottom = -8.0
	cl.add_child(_hint)

func _process(_delta: float) -> void :


	if _hint:
		_hint.visible = not (_debug_open or end_panel.visible or results_screen.visible\
		or time_card.visible or _glasses_on)

func _input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if not _debug_open and _debug_can_open():
			_open_debug()
		get_viewport().set_input_as_handled()




func _debug_can_open() -> bool:
	if end_panel.visible or results_screen.visible:
		return false
	if time_card.visible or _glasses_on:
		return false
	if DialogueManager._advance_locked:
		return false
	return true

func _open_debug() -> void :
	_debug_open = true
	if _hint:
		_hint.visible = false
	_debug.open()
	get_tree().paused = true

func _close_debug() -> void :
	if not _debug_open:
		return
	_debug_open = false
	get_tree().paused = false
	_debug.close()




func _setup_glasses_blur() -> void :
	$UILayer.layer = 10
	var sl: = CanvasLayer.new()
	sl.name = "StageBlurLayer"
	sl.layer = 5
	add_child(sl)
	_stage_bbc = BackBufferCopy.new()
	_stage_bbc.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	sl.add_child(_stage_bbc)
	_stage_blur = _make_blur_rect()
	sl.add_child(_stage_blur)
	var fl: = CanvasLayer.new()
	fl.name = "FrontBlurLayer"
	fl.layer = 20
	add_child(fl)
	_front_bbc = BackBufferCopy.new()
	_front_bbc.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	fl.add_child(_front_bbc)
	_front_blur = _make_blur_rect()
	fl.add_child(_front_blur)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = OPEN_CUTOFF
	AudioServer.add_bus_effect(0, _lowpass)

func _make_blur_rect() -> ColorRect:
	var r: = ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: = ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	mat.set_shader_parameter("amount", 0.0)
	r.material = mat
	r.visible = false
	return r


func _start_glasses_blur() -> void :
	if _glasses_on:
		return
	_glasses_on = true
	_stage_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_front_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_stage_blur.visible = true
	_front_blur.visible = true
	if _blur_tween and _blur_tween.is_valid():
		_blur_tween.kill()
	_blur_tween = create_tween().set_parallel(true)
	_blur_tween.tween_method( func(v: float): _stage_blur.material.set_shader_parameter("amount", v), 0.0, stage_blur_amount, blur_fade)
	_blur_tween.tween_method( func(v: float): _front_blur.material.set_shader_parameter("amount", v), 0.0, front_blur_amount, blur_fade)
	_blur_tween.tween_method( func(v: float): _lowpass.cutoff_hz = v, OPEN_CUTOFF, muffle_cutoff, blur_fade)


func _clear_glasses_blur() -> void :
	if _blur_tween and _blur_tween.is_valid():
		_blur_tween.kill()
	_glasses_on = false
	if _stage_blur:
		_stage_blur.visible = false
		_stage_blur.material.set_shader_parameter("amount", 0.0)
	if _front_blur:
		_front_blur.visible = false
		_front_blur.material.set_shader_parameter("amount", 0.0)
	if _stage_bbc:
		_stage_bbc.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	if _front_bbc:
		_front_bbc.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	if _lowpass:
		_lowpass.cutoff_hz = OPEN_CUTOFF




func _style_end_panel() -> void :
	end_panel.theme = load("res://ui/clinical.tres")
	var sb: = UIStyle.ending_stylebox()
	sb.content_margin_left = 40.0
	sb.content_margin_top = 32.0
	sb.content_margin_right = 40.0
	sb.content_margin_bottom = 32.0
	end_panel.add_theme_stylebox_override("panel", sb)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.label_bold(end_title, UIStyle.SIZE_VERDICT, UIStyle.VERDICT_COLOR)
	UIStyle.rich_body(end_body, UIStyle.SIZE_PROSE, UIStyle.TEXT_SECONDARY)
	restart_button.add_theme_font_override("font", UIStyle.font_body())

func _on_location_changed(location: String) -> void :
	var path: Variant = LOCATION_SCENES.get(location)
	if path == null:
		push_warning("Main: no scene for location '%s'" % location)
		return
	_swap_stage(path)

func _on_line_shown(_speaker: String, text: String, _is_last: bool) -> void :
	var t: = text.to_lower()
	if t.find(TIME_CARD_LINE) != -1:

		_time_card_pending = true
		DialogueManager.set_advance_locked(true)
		return

	if DialogueManager.current_id == GLASSES_NODE and DialogueManager._line_index == GLASSES_LINE_INDEX:
		_start_glasses_blur()
	for entry in LINE_STAGE:
		if t.find(entry["needle"]) != -1:
			_swap_stage(entry["scene"])
			return



func _on_user_advanced() -> void :
	if _time_card_pending:
		_time_card_pending = false





		MusicManager.set_music_state(MusicManager.State.BISTRO_PAN)
		Sfx.play_ambience("longshot_ambience", 2.0)
		await time_card.play_and_wait("19:00")
		DialogueManager.set_advance_locked(false)
		DialogueManager.advance()





func _swap_stage(scene_path: String, force: bool = false) -> void :
	if scene_path == _current_stage_path and not force:
		return
	_current_stage_path = scene_path
	if _stage_instance != null:
		if force:
			_stage_instance.free()
		else:
			_stage_instance.queue_free()
		_stage_instance = null
	var packed: PackedScene = load(scene_path)
	_stage_instance = packed.instantiate()
	stage.add_child(_stage_instance)

func _on_run_ended(kind: String, info: Dictionary) -> void :
	if kind == "prey":



		await _play_prey_transformation()
		end_panel.visible = true
		end_title.text = "PREY"
		end_body.text = "Idimya devours you."
		restart_button.grab_focus()
		_typewriter_prey()
	else:


		var outcome: = OutcomeCalculator.compute(RunState)




		if str(outcome.get("verdict", "")) == "RIVAL" and not bool(outcome.get("secret_crush", false)):
			await _play_prey_transformation()
		results_screen.show_results(outcome, RunState.cras_dict())


func _typewriter_prey() -> void :
	end_title.visible_ratio = 1.0
	end_body.visible_ratio = 0.0
	var tw: = create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(end_body, "visible_ratio", 1.0, maxf(0.3, float(end_body.get_total_character_count()) / UIStyle.TYPE_CPS))



func _play_prey_transformation() -> void :
	if _stage_instance != null and _stage_instance.has_method("play_transformation"):
		await _stage_instance.play_transformation()



func show_results_preview() -> void :
	results_screen.show_results(OutcomeCalculator.compute(RunState), RunState.cras_dict())

func _restart() -> void :
	new_run()






func new_run() -> void :
	_clear_glasses_blur()
	end_panel.visible = false
	results_screen.visible = false
	SaveManager.reset_playtime()
	MusicManager.begin()
	DialogueManager.start_new_run()





const SKIP_INTRO_NODE: = "1"
const SKIP_INTRO_LINE: = 11

func new_run_skip_intro() -> void :
	_clear_glasses_blur()
	end_panel.visible = false
	results_screen.visible = false
	SaveManager.reset_playtime()
	RunState.reset()
	DialogueManager.set_path_history([])
	_swap_stage("res://scenes/MainDate.tscn", true)
	if _stage_instance and _stage_instance.has_method("enter_post_intro"):
		_stage_instance.enter_post_intro()
	MusicManager.begin(MusicManager.State.MAIN)
	DialogueManager.goto(SKIP_INTRO_NODE, SKIP_INTRO_LINE, true)




func build_snapshot() -> Dictionary:
	var pos: = DialogueManager.capture_position()
	return {
		"save_version": SaveManager.SAVE_VERSION, 
		"timestamp_unix": int(Time.get_unix_time_from_system()), 
		"timestamp_str": SaveManager.format_datetime(Time.get_datetime_dict_from_system()), 
		"playtime_seconds": SaveManager.playtime, 
		"run_state": {
			"C": RunState.C, "R": RunState.R, "A": RunState.A, "S": RunState.S, 
			"flags": RunState.flags.duplicate(true), 
		}, 
		"dialogue_position": pos, 
		"path_history": DialogueManager.get_path_history(), 
		"presentation_state": {
			"stage_path": _current_stage_path, 
			"music_state": MusicManager._state, 
		}, 
	}

func save_run() -> String:
	return SaveManager.write_snapshot(build_snapshot())




func load_snapshot(data: Dictionary) -> void :
	_clear_glasses_blur()
	end_panel.visible = false
	results_screen.visible = false

	var rs: Dictionary = data.get("run_state", {})
	RunState.C = int(rs.get("C", 0))
	RunState.R = int(rs.get("R", 0))
	RunState.A = int(rs.get("A", 0))
	RunState.S = int(rs.get("S", 0))
	RunState.flags = (rs.get("flags", {}) as Dictionary).duplicate(true)
	RunState.changed.emit()
	DialogueManager.set_path_history(data.get("path_history", []))
	SaveManager.playtime = float(data.get("playtime_seconds", 0.0))

	var pres: Dictionary = data.get("presentation_state", {})
	var stage_path: = str(pres.get("stage_path", "res://scenes/MainDate.tscn"))
	_swap_stage(stage_path, true)
	if _stage_instance and _stage_instance.has_method("enter_post_intro") and str(data.get("dialogue_position", {}).get("node_id", "")) != "intro":
		_stage_instance.enter_post_intro()
	MusicManager.begin(int(pres.get("music_state", MusicManager.State.MAIN)))

	var pos: Dictionary = data.get("dialogue_position", {})


	DialogueManager.restore(str(pos.get("node_id", "")), int(pos.get("line_index", 0)), bool(pos.get("awaiting_choice", false)))
