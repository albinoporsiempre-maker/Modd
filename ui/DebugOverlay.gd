extends CanvasLayer





const OutcomeCalculator: = preload("res://scripts/OutcomeCalculator.gd")

@onready var panel: PanelContainer = %Panel
@onready var info_label: RichTextLabel = %InfoLabel
@onready var jump_edit: LineEdit = %JumpEdit
@onready var validation_label: RichTextLabel = %ValidationLabel

var _visible_state: bool = false

func _ready() -> void :
	panel.visible = false
	RunState.changed.connect(_refresh)
	MetaState.changed.connect(_refresh)
	DialogueManager.state_changed.connect(_refresh)
	%JumpButton.pressed.connect(_on_jump)
	jump_edit.text_submitted.connect( func(_t): _on_jump())
	%RestartButton.pressed.connect( func(): DialogueManager.start_new_run())
	%ClearMetaButton.pressed.connect( func(): MetaState.clear_all();_refresh())
	%PreviewButton.pressed.connect(_on_preview_results)
	%CplusButton.pressed.connect( func(): _bump("C", 1))
	%CminusButton.pressed.connect( func(): _bump("C", -1))
	%RplusButton.pressed.connect( func(): _bump("R", 1))
	%RminusButton.pressed.connect( func(): _bump("R", -1))
	%AplusButton.pressed.connect( func(): _bump("A", 1))
	%AminusButton.pressed.connect( func(): _bump("A", -1))
	%SplusButton.pressed.connect( func(): _bump("S", 1))
	%SminusButton.pressed.connect( func(): _bump("S", -1))
	_refresh()

func _input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_visible_state = not _visible_state
		panel.visible = _visible_state
		if _visible_state:
			_refresh()

func _bump(field: String, amount: int) -> void :
	RunState.apply_cras({field: amount})
	_refresh()




func _on_preview_results() -> void :
	var raw: = ( %CrasEdit as LineEdit).text.strip_edges()
	if raw != "":
		var parts: = raw.split(" ", false)
		if parts.size() == 4:
			RunState.C = int(parts[0])
			RunState.R = int(parts[1])
			RunState.A = int(parts[2])
			RunState.S = int(parts[3])
			RunState.changed.emit()
		else:
			push_warning("DebugOverlay: expected 'C R A S' (4 numbers)")
	var main: = get_tree().current_scene
	if main and main.has_method("show_results_preview"):
		main.show_results_preview()
	_refresh()

func _on_jump() -> void :
	var id: = jump_edit.text.strip_edges()
	if id == "":
		return
	if GameData.has_node_id(id):
		DialogueManager.enter(id)
	else:
		push_warning("DebugOverlay: no node '%s'" % id)

func _refresh() -> void :
	if not panel.visible:
		return
	var rs: = RunState
	var lines: Array[String] = []
	lines.append("[b]node:[/b] %s" % DialogueManager.current_id)
	var nd: = DialogueManager.current_node()
	lines.append("  design_id: %s  kind: %s" % [nd.get("design_id", "-"), nd.get("kind", "-")])
	lines.append("[b]CRAS[/b]  C=%d  R=%d  A=%d  S=%d" % [rs.C, rs.R, rs.A, rs.S])
	var oc: = OutcomeCalculator.compute(rs)
	lines.append("  [i]if outcome now:[/i] %s / %s%s" % [oc["compass"], oc["verdict"], " +crush" if oc["secret_crush"] else ""])
	lines.append("[b]run flags[/b]")
	var keys: = rs.flags.keys()
	keys.sort()
	for k in keys:
		lines.append("  %s = %s" % [k, str(rs.flags[k])])
	lines.append("[b]meta flags (persistent)[/b]")
	if MetaState.flags.is_empty():
		lines.append("  (none)")
	for k in MetaState.flags.keys():
		lines.append("  %s = %s" % [k, str(MetaState.flags[k])])
	info_label.text = "\n".join(lines)

	if GameData.validation_errors.is_empty():
		validation_label.text = "[color=#7CFC00]dialogue validation OK[/color]"
	else:
		validation_label.text = "[color=#FF6347]%d validation error(s) — see Output[/color]" % GameData.validation_errors.size()
