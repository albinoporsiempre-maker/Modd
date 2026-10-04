extends Node









signal changed

var C: int = 0
var R: int = 0
var A: int = 0
var S: int = 0



var flags: Dictionary = {}

func reset() -> void :
	C = 0
	R = 0
	A = 0
	S = 0
	flags.clear()
	changed.emit()

func apply_cras(delta: Dictionary) -> void :

	for k in delta.keys():
		if k not in ["C", "R", "A", "S"]:
			push_warning("RunState: ignoring unknown CRAS key '%s'" % k)
			continue
		var v: Variant = delta[k]
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			push_warning("RunState: non-numeric CRAS delta for '%s'" % k)
			continue
		match k:
			"C": C += int(v)
			"R": R += int(v)
			"A": A += int(v)
			"S": S += int(v)
	changed.emit()

func set_flag(name: String, value: Variant = true) -> void :
	flags[name] = value
	changed.emit()

func has_flag(name: String) -> bool:
	return flags.has(name) and flags[name] != false

func get_flag(name: String, default: Variant = null) -> Variant:
	return flags.get(name, default)

func cras_dict() -> Dictionary:
	return {"C": C, "R": R, "A": A, "S": S}
