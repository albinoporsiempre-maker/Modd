extends Node





const OutcomeCalculator: = preload("res://scripts/OutcomeCalculator.gd")
const Conditions: = preload("res://scripts/Conditions.gd")

signal node_entered(node_id: String)
signal location_changed(location: String)
signal line_shown(speaker: String, text: String, is_last: bool)
signal choices_shown(choices: Array)
signal run_ended(kind: String, info: Dictionary)
signal state_changed


signal run_reset

var current_id: String = ""
var _line_index: int = 0
var _awaiting_choice: bool = false
var _advance_locked: bool = false


var _path_history: Array = []
var _last_choices: Array = []




func start_new_run() -> void :
	run_reset.emit()
	RunState.reset()
	_awaiting_choice = false
	_advance_locked = false
	_path_history.clear()
	enter(GameData.start_node)

func current_node() -> Dictionary:
	return GameData.get_node_data(current_id)




func enter(node_id: String) -> void :
	if not GameData.has_node_id(node_id):
		push_error("DialogueManager: attempted to enter missing node '%s'" % node_id)
		return
	var prev_loc: = ""
	if current_id != "":
		prev_loc = current_node().get("location", "")
	current_id = node_id
	_awaiting_choice = false
	var n: = current_node()

	_apply_effects(n)

	var loc: String = n.get("location", "")
	if loc != "" and loc != prev_loc:
		location_changed.emit(loc)

	node_entered.emit(node_id)
	state_changed.emit()

	_line_index = 0
	_present()

func _apply_effects(n: Dictionary) -> void :
	var cras: Dictionary = n.get("cras", {})
	if not cras.is_empty():
		RunState.apply_cras(cras)
	for flag in n.get("sets", []):
		RunState.set_flag(flag, true)
	var sem: Variant = n.get("semantic_sets")
	if typeof(sem) == TYPE_DICTIONARY:
		for k in sem.keys():
			RunState.set_flag(k, sem[k])
	for mflag in n.get("meta_sets", []):
		MetaState.set_flag(mflag, true)




func _present() -> void :
	var n: = current_node()
	var lines: Array = n.get("lines", [])
	if _line_index < lines.size():
		var line: Dictionary = lines[_line_index]
		var is_last: bool = _line_index == lines.size() - 1
		line_shown.emit(line.get("speaker", "you"), line.get("text", ""), is_last)
	else:
		_resolve()





func set_advance_locked(locked: bool) -> void :
	_advance_locked = locked

func advance() -> void :
	if _awaiting_choice or _advance_locked:
		return
		if AIManager and AIManager.free_will_active:
		var ui = get_tree().get_first_node_in_group("dialogue_box")
		if ui and ui.has_method("show_free_will_ui"):
			ui.show_free_will_ui()
		return
	var lines: Array = current_node().get("lines", [])
	if _line_index < lines.size() - 1:
		_line_index += 1
		_present()
	else:
		_resolve()

func apply_free_will_data(data: Dictionary) -> void :
	if data.has("cras"): RunState.apply_cras(data["cras"])
	if data.has("flags"):
		for f in data["flags"]: RunState.set_flag(str(f))

func choose(child_id: String) -> void :
	if not _awaiting_choice:
		return
	_awaiting_choice = false

	var idx: = -1
	var txt: = ""
	for i in _last_choices.size():
		if str(_last_choices[i].get("id", "")) == child_id:
			idx = i
			txt = str(_last_choices[i].get("label", ""))
			break
	_path_history.append({
		"node_id": current_id, 
		"choice_index": idx, 
		"target_node_id": child_id, 
		"choice_text": txt, 
	})
	enter(child_id)

func _resolve() -> void :
	var n: = current_node()
	var kind: String = n.get("kind", "line")
	match kind:
		"prey":
			run_ended.emit("prey", {"node": current_id})
		"ending":
			run_ended.emit("ending", {"node": current_id, "key": n.get("ending_key", "")})
		"outcome":
			var result: = OutcomeCalculator.compute(RunState)
			var ending_node: String = result["ending_node"]
			if not GameData.has_node_id(ending_node):
				push_error("DialogueManager: computed ending '%s' missing" % ending_node)
				run_ended.emit("ending", result)
				return
			enter(ending_node)
		"sequence":
			var kids: Array = n.get("children", [])
			if kids.is_empty():
				push_error("DialogueManager: sequence '%s' has no child" % current_id)
			else:
				enter(kids[0])
		"branch":
			var picked: = _pick_branch(n)
			if picked == "":
				push_error("DialogueManager: branch '%s' matched no condition" % current_id)
			else:
				enter(picked)
		"choices":
			_present_choices(n)
		"line":
			var goto: Variant = n.get("goto")
			if goto == null:
				push_warning("DialogueManager: line '%s' has no goto; ending quietly" % current_id)
			elif goto == "@outcome":
				var result: = OutcomeCalculator.compute(RunState)
				enter(result["ending_node"])
			else:
				enter(goto)
		_:
			push_error("DialogueManager: unknown node kind '%s'" % kind)

func _pick_branch(n: Dictionary) -> String:
	for c in n.get("children", []):
		var child: = GameData.get_node_data(c)
		if Conditions.evaluate(child.get("requires")):
			return c
	return ""

func _present_choices(n: Dictionary) -> void :
	var out: Array = []
	for c in n.get("children", []):
		var child: = GameData.get_node_data(c)
		if Conditions.evaluate(child.get("requires")):
			out.append({"id": c, "label": _choice_label(child)})
	if out.is_empty():
		push_error("DialogueManager: choices node '%s' has no available option" % current_id)
		return
	_last_choices = out
	_awaiting_choice = true
	choices_shown.emit(out)

func _choice_label(child: Dictionary) -> String:
	var l: String = child.get("label", "")
	if l.strip_edges() == "":
		l = "(" + child.get("design_id", child.get("id", "?")) + ")"
	return l




func get_path_history() -> Array:
	return _path_history.duplicate(true)

func set_path_history(h: Array) -> void :
	_path_history = h.duplicate(true)

func capture_position() -> Dictionary:
	return {"node_id": current_id, "line_index": _line_index, "awaiting_choice": _awaiting_choice}



func _position_header(node_id: String, apply_effects: bool) -> Array:
	var prev_loc: = ""
	if current_id != "":
		prev_loc = current_node().get("location", "")
	current_id = node_id
	_awaiting_choice = false
	_advance_locked = false
	var n: = current_node()
	if apply_effects:
		_apply_effects(n)
	var loc: String = n.get("location", "")
	if loc != "" and loc != prev_loc:
		location_changed.emit(loc)
	node_entered.emit(node_id)
	state_changed.emit()
	return n.get("lines", [])




func goto(node_id: String, line_index: int = 0, apply_effects: bool = false) -> void :
	if not GameData.has_node_id(node_id):
		push_error("DialogueManager: goto missing node '%s'" % node_id)
		return
	run_reset.emit()
	var lines: = _position_header(node_id, apply_effects)
	_line_index = clampi(line_index, 0, maxi(0, lines.size() - 1))
	_present()



func restore(node_id: String, line_index: int, awaiting: bool) -> void :
	if not GameData.has_node_id(node_id):
		push_error("DialogueManager: restore missing node '%s'" % node_id)
		return
	run_reset.emit()
	var lines: = _position_header(node_id, false)
	if awaiting:
		_line_index = maxi(0, lines.size() - 1)



		if _line_index < lines.size():
			var line: Dictionary = lines[_line_index]
			line_shown.emit(line.get("speaker", "you"), line.get("text", ""), true)
		_present_choices(current_node())
	else:
		_line_index = clampi(line_index, 0, maxi(0, lines.size() - 1))
		_present()
