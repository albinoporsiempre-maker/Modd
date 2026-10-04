extends Control
class_name RouteGraph














const COL_W: = 50.0
const ROW_H: = 16.0
const PAD: = Vector2(22.0, 20.0)

static var _topo_cache: Dictionary = {}


var _pos: Dictionary = {}
var _edges: Array = []
var _start_id: String = ""
var _tree_size: Vector2 = Vector2.ZERO

var _visited: Dictionary = {}
var _seq: Array = []
var _sel: int = -1
var _focused: bool = false

var _cam: Vector2 = Vector2.ZERO
var _cam_target: Vector2 = Vector2.ZERO
var _cam_init: bool = false


const C_CROSS: = Color(0.2, 0.2, 0.19, 0.55)
const C_TREE: = Color(0.29, 0.28, 0.26)
const C_DIM_DOT: = Color(0.34, 0.33, 0.3)
const C_VIS_EDGE: = Color(0.6, 0.57, 0.51)
const C_VIS_DOT: = Color(0.7, 0.67, 0.6)
const C_SEL_DOT: = Color(0.97, 0.95, 0.9)

const R_DIM: = 2.3
const R_VIS: = 3.4
const R_SEL: = 5.0

func _ready() -> void :
	clip_contents = true
	set_process(true)
	resized.connect(_on_resized)

func _on_resized() -> void :


	_retarget_camera(true)




func set_route(path_history: Array) -> void :
	var topo: = _get_topology()
	_pos = topo.get("pos", {})
	_edges = topo.get("edges", [])
	_start_id = topo.get("start", "")
	_tree_size = topo.get("size", Vector2.ZERO)

	_visited = {}
	_seq = []
	if _start_id != "":
		_visited[_start_id] = true
	for e in path_history:
		var nid: = str(e.get("node_id", ""))
		var tid: = str(e.get("target_node_id", ""))
		var txt: = str(e.get("choice_text", "")).strip_edges()
		if _pos.has(nid):
			_visited[nid] = true
		if _pos.has(tid):
			_visited[tid] = true
			_seq.append({"id": tid, "text": txt})

	_sel = _seq.size() - 1
	_retarget_camera(true)
	queue_redraw()

func set_focused(v: bool) -> void :
	if _focused == v:
		return
	_focused = v
	queue_redraw()



func move_selection(dir: int) -> bool:
	if not _focused or _seq.is_empty():
		return false
	var n: = clampi(_sel + dir, 0, _seq.size() - 1)
	if n == _sel:
		return false
	_sel = n
	_retarget_camera(false)
	queue_redraw()
	return true

func selected_text() -> String:
	if _sel >= 0 and _sel < _seq.size():
		return str(_seq[_sel].get("text", ""))
	return ""




func _retarget_camera(instant: bool) -> void :
	var p: Variant = _selected_pos()
	if p == null:
		return
	var vs: = size
	if vs.x < 4.0 or vs.y < 4.0:
		return


	var want: = (p as Vector2) - Vector2(vs.x * 0.38, vs.y * 0.5)


	var maxx: float = maxf(0.0, _tree_size.x - vs.x)
	var maxy: float = maxf(0.0, _tree_size.y - vs.y)
	want.x = clampf(want.x, 0.0, maxx)
	want.y = clampf(want.y, 0.0, maxy)
	if _tree_size.y < vs.y:
		want.y = (_tree_size.y - vs.y) * 0.5
	_cam_target = want
	if instant or not _cam_init:
		_cam = want
		_cam_init = true
		queue_redraw()

func _process(delta: float) -> void :
	if not _cam_init:
		return
	if _cam.distance_to(_cam_target) < 0.4:
		if _cam != _cam_target:
			_cam = _cam_target
			queue_redraw()
		return

	var t: = clampf(delta * 11.0, 0.0, 1.0)
	_cam = _cam.lerp(_cam_target, t)
	queue_redraw()

func _selected_pos():
	if _sel >= 0 and _sel < _seq.size():
		var sid: String = _seq[_sel].get("id", "")
		if _pos.has(sid):
			return _pos[sid]
	return null




func _draw() -> void :
	if _pos.is_empty():
		return
	var vs: = size
	var view: = Rect2(_cam - Vector2(40, 40), vs + Vector2(80, 80))


	for e in _edges:
		if not _pos.has(e.from) or not _pos.has(e.to):
			continue
		if _visited.has(e.from) and _visited.has(e.to):
			continue
		var a: Vector2 = _pos[e.from]
		var b: Vector2 = _pos[e.to]
		if not _seg_in(a, b, view):
			continue
		_elbow(a, b, C_TREE if e.tree else C_CROSS, 1.0)


	for e in _edges:
		if not (_visited.has(e.from) and _visited.has(e.to)):
			continue
		var a: Vector2 = _pos[e.from]
		var b: Vector2 = _pos[e.to]
		if not _seg_in(a, b, view):
			continue
		_elbow(a, b, C_VIS_EDGE, 1.7)


	for id in _pos:
		var p: Vector2 = _pos[id]
		if not view.has_point(p):
			continue
		if _visited.has(id):
			draw_circle(p - _cam, R_VIS, C_VIS_DOT)
		else:
			draw_circle(p - _cam, R_DIM, C_DIM_DOT)


	if _focused:
		var sp = _selected_pos()
		if sp != null:
			var s: Vector2 = (sp as Vector2) - _cam
			draw_circle(s, R_SEL, C_SEL_DOT)
			draw_arc(s, R_SEL + 3.0, 0.0, TAU, 22, C_SEL_DOT, 1.2, true)
			_draw_label(s, selected_text())

func _draw_label(anchor: Vector2, text: String) -> void :
	text = text.strip_edges()
	if text == "":
		return
	var font: = UIStyle.font_body()
	var fsize: = 13
	var vs: = size
	var wrap: = 190.0

	var x: = anchor.x + 10.0
	var right_est: = x + wrap
	if right_est > vs.x - 6.0:
		x = anchor.x - 10.0 - wrap
	x = clampf(x, 4.0, maxf(4.0, vs.x - wrap - 4.0))
	var y: = anchor.y - float(fsize)
	y = clampf(y, float(fsize) + 2.0, maxf(float(fsize) + 2.0, vs.y - float(fsize) * 3.0))
	draw_multiline_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, 
		wrap, fsize, 3, UIStyle.TEXT_PRIMARY)

func _elbow(a: Vector2, b: Vector2, col: Color, w: float) -> void :

	var a2: = a - _cam
	var b2: = b - _cam
	var midx: = a2.x + (b2.x - a2.x) * 0.5
	if absf(a2.y - b2.y) < 0.5:
		draw_line(a2, b2, col, w, true)
		return
	draw_line(a2, Vector2(midx, a2.y), col, w, true)
	draw_line(Vector2(midx, a2.y), Vector2(midx, b2.y), col, w, true)
	draw_line(Vector2(midx, b2.y), b2, col, w, true)

func _seg_in(a: Vector2, b: Vector2, view: Rect2) -> bool:
	var lo: = Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi: = Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return view.intersects(Rect2(lo, hi - lo))




static func _get_topology() -> Dictionary:
	if not _topo_cache.is_empty():
		return _topo_cache
	_topo_cache = _build_topology()
	return _topo_cache

static func _is_kept(id: String) -> bool:
	if not GameData.has_node_id(id):
		return false
	var k: = str(GameData.get_node_data(id).get("kind", ""))
	return k != "prey" and k != "outcome" and k != "ending"

static func _out_edges(id: String) -> Array:
	var n: = GameData.get_node_data(id)
	var outs: Array = []
	for c in n.get("children", []):
		var cs: = str(c)
		if _is_kept(cs) and not outs.has(cs):
			outs.append(cs)
	var g: Variant = n.get("goto")
	if typeof(g) == TYPE_STRING and g != "" and g != "@outcome" and g != id and _is_kept(g) and not outs.has(g):
		outs.append(g)
	return outs

static func _build_topology() -> Dictionary:
	var start: = str(GameData.start_node)
	if not _is_kept(start):
		return {"pos": {}, "edges": [], "start": "", "size": Vector2.ZERO}


	var order: Dictionary = {}
	var nodes: Array = []
	var adj: Dictionary = {}
	var seen: Dictionary = {}
	var st: Array = [start]
	var idx: = 0
	while not st.is_empty():
		var cur: String = st.pop_back()
		if seen.has(cur):
			continue
		seen[cur] = true
		order[cur] = idx
		idx += 1
		nodes.append(cur)
		var outs: = _out_edges(cur)
		adj[cur] = outs
		for i in range(outs.size() - 1, -1, -1):
			if not seen.has(outs[i]):
				st.push_back(outs[i])


	var preds: Dictionary = {}
	for id in nodes:
		preds[id] = []
	for u in nodes:
		for v in adj[u]:
			(preds[v] as Array).append(u)


	var layer: Dictionary = {}
	for id in nodes:
		layer[id] = 0
	for _pass in range(nodes.size()):
		var changed: = false
		for u in nodes:
			for v in adj[u]:
				if int(layer[u]) + 1 > int(layer[v]):
					layer[v] = int(layer[u]) + 1
					changed = true
		if not changed:
			break


	var primary: Dictionary = {}
	var tree_children: Dictionary = {}
	for id in nodes:
		tree_children[id] = []
	for id in nodes:
		if id == start:
			continue
		var best: String = ""
		for p in preds[id]:
			if best == "" or int(layer[p]) < int(layer[best])\
			or (int(layer[p]) == int(layer[best]) and str(p) < str(best)):
				best = p
		primary[id] = best
		if best != "":
			(tree_children[best] as Array).append(id)
	for id in nodes:
		(tree_children[id] as Array).sort_custom( func(a, b): return int(order[a]) < int(order[b]))


	var yb: Dictionary = {}
	var counter: Array = [0.0]
	_layout_y(start, tree_children, yb, counter)


	var pos: Dictionary = {}
	var maxx: = 0.0
	var maxy: = 0.0
	for id in nodes:
		var p: = Vector2(PAD.x + float(layer[id]) * COL_W, PAD.y + float(yb[id]) * ROW_H)
		pos[id] = p
		maxx = maxf(maxx, p.x)
		maxy = maxf(maxy, p.y)


	var edges: Array = []
	for u in nodes:
		for v in adj[u]:
			edges.append({"from": u, "to": v, "tree": str(primary.get(v, "")) == u})

	return {
		"pos": pos, 
		"edges": edges, 
		"start": start, 
		"size": Vector2(maxx + PAD.x, maxy + PAD.y), 
	}

static func _layout_y(id: String, tc: Dictionary, yb: Dictionary, counter: Array) -> void :
	var kids: Array = tc.get(id, [])
	if kids.is_empty():
		yb[id] = counter[0]
		counter[0] += 1.0
		return
	for k in kids:
		_layout_y(k, tc, yb, counter)
	yb[id] = (float(yb[kids[0]]) + float(yb[kids[kids.size() - 1]])) * 0.5
