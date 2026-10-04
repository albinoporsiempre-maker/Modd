extends RefCounted







static func compute(rs: Node = RunState) -> Dictionary:
	var c: int = rs.C
	var r: int = rs.R
	var a: int = rs.A
	var s: int = rs.S

	var compass: String
	if c > 0 and r > 0:
		compass = "FASCINATED"
	elif c > 0 and r <= 0:
		compass = "OBSESSIVE"
	elif c <= 0 and r > 0:
		compass = "COEXISTENT"
	else:
		compass = "PREDATORY"

	var aligned: bool = c <= -2 and r <= -3
	var verdict: String = "ALLY" if (aligned or a >= 4) else "RIVAL"
	var secret_crush: bool = s >= 4

	var key: String = verdict.to_lower()
	if secret_crush:
		key += "_crush"

	return {
		"compass": compass, 
		"aligned": aligned, 
		"verdict": verdict, 
		"secret_crush": secret_crush, 
		"key": key, 
		"ending_node": "ending_" + key, 

		"spared": verdict == "RIVAL" and secret_crush, 
	}
