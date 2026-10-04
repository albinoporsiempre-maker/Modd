extends Node




const DATA_PATH: = "res://data/dialogue.json"

var nodes: Dictionary = {}
var start_node: String = "intro"
var validation_errors: Array[String] = []

func _ready() -> void :
	_load()
	_validate()

func _load() -> void :
	var f: = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: dialogue.json is malformed")
		return
	var d: Dictionary = parsed
	nodes = d.get("nodes", {})
	var meta: Dictionary = d.get("meta", {})
	start_node = meta.get("start_node", "intro")
	print("GameData: loaded %d nodes (start=%s)" % [nodes.size(), start_node])

func has_node_id(id: String) -> bool:
	return nodes.has(id)

func get_node_data(id: String) -> Dictionary:
	return nodes.get(id, {})



func _validate() -> void :
	validation_errors.clear()
	if not nodes.has(start_node):
		_err("start node '%s' does not exist" % start_node)
	for id in nodes.keys():
		var n: Dictionary = nodes[id]
		var goto: Variant = n.get("goto")
		if goto != null and goto != "@outcome" and not nodes.has(goto):
			_err("node '%s' goto -> missing '%s'" % [id, goto])
		for c in n.get("children", []):
			if not nodes.has(c):
				_err("node '%s' child -> missing '%s'" % [id, c])
		var kind: String = n.get("kind", "")
		if kind == "line" and goto == null and n.get("children", []).is_empty():
			_err("node '%s' is a dead end (line with no goto/children)" % id)
		if kind == "branch":
			for c in n.get("children", []):
				if nodes[c].get("requires") == null:
					_err("branch '%s' child '%s' has no condition" % [id, c])
		var req: Variant = n.get("requires")
		if req != null:
			for term in req.get("terms", []):
				var tok: String = term.get("token", "")
				if tok != "9.3" and not _design_id_exists(tok):
					_err("condition token '%s' in '%s' references unknown design id" % [tok, id])
	if validation_errors.is_empty():
		print("GameData: validation OK")
	else:
		for e in validation_errors:
			push_warning("GameData validation: " + e)

func _design_id_exists(design_id: String) -> bool:
	for id in nodes.keys():
		if nodes[id].get("design_id", "") == design_id:
			return true
	return false

func _err(msg: String) -> void :
	validation_errors.append(msg)
