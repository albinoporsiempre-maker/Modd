extends RefCounted










static func evaluate(requires: Variant) -> bool:
	if requires == null:
		return true
	if typeof(requires) != TYPE_DICTIONARY:
		push_warning("Conditions: malformed requires (not a dict)")
		return true
	var terms: Array = requires.get("terms", [])
	if terms.is_empty():
		return true
	var op: String = requires.get("op", "and")
	var results: Array[bool] = []
	for term in terms:
		results.append(_eval_term(term))
	if op == "or":
		return results.has(true)
	return not results.has(false)

static func _eval_term(term: Dictionary) -> bool:
	var token: String = term.get("token", "")
	var want: bool = term.get("value", true)
	var actual: bool
	if token == "9.3":
		actual = MetaState.has_flag("knows_idimya_likes_blood")
	else:
		actual = RunState.has_flag("picked:" + token)
	return actual == want
