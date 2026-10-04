extends Control











@export var c_min: float = -8.0
@export var c_max: float = 6.0
@export var r_min: float = -10.0
@export var r_max: float = 6.0





@export var idimya_unit: Vector2 = Vector2(1.0, -1.0)



const COLOR_IDIMYA: = Color(0.85, 0.52, 0.3)
const COLOR_YOU: = Color(0.52, 0.72, 0.75)


const COLOR_BORDER: = Color(0.56, 0.53, 0.5, 0.9)
const COLOR_AXIS: = Color(0.56, 0.53, 0.5, 0.7)
const COLOR_QUAD: = Color(0.72, 0.69, 0.65, 1.0)
const COLOR_AXISLABEL: = Color(0.905, 0.882, 0.839)

const MARGIN_LR: = 82.0
const MARGIN_TB: = 30.0
const MARKER_RADIUS: = 7.0

var _player_c: float = 0.0
var _player_r: float = 0.0
var _has_player: bool = false

func set_player(c: float, r: float) -> void :
	_player_c = c
	_player_r = r
	_has_player = true
	queue_redraw()




static func cr_to_unit(c: float, r: float, cmin: float, cmax: float, rmin: float, rmax: float) -> Vector2:
	var y: float
	if c >= 0.0:
		y = (min(c, cmax) / cmax) if cmax > 0.0 else 0.0
	else:
		y = - (max(c, cmin) / cmin) if cmin < 0.0 else 0.0
	var x: float
	if r >= 0.0:
		x = - ((min(r, rmax) / rmax) if rmax > 0.0 else 0.0)
	else:
		x = (max(r, rmin) / rmin) if rmin < 0.0 else 0.0
	return Vector2(clampf(x, -1.0, 1.0), clampf(y, -1.0, 1.0))

func _draw() -> void :



	var font: = UIStyle.font_body()
	var fs: = 16
	var fs_small: = 15

	var avail: = Vector2(size.x - 2.0 * MARGIN_LR, size.y - 2.0 * MARGIN_TB)
	var side: = minf(avail.x, avail.y)
	if side <= 0.0:
		return
	var origin: = Vector2((size.x - side) / 2.0, (size.y - side) / 2.0)
	var center: = origin + Vector2(side / 2.0, side / 2.0)
	var half: = side / 2.0


	draw_rect(Rect2(origin, Vector2(side, side)), COLOR_BORDER, false, 1.5)
	draw_line(Vector2(center.x, origin.y), Vector2(center.x, origin.y + side), COLOR_AXIS, 1.0)
	draw_line(Vector2(origin.x, center.y), Vector2(origin.x + side, center.y), COLOR_AXIS, 1.0)


	_centered_text(font, fs_small, origin + Vector2(side * 0.25, side * 0.25), "COEXISTENT", COLOR_QUAD)
	_centered_text(font, fs_small, origin + Vector2(side * 0.75, side * 0.25), "PREDATORY", COLOR_QUAD)
	_centered_text(font, fs_small, origin + Vector2(side * 0.25, side * 0.75), "FASCINATED", COLOR_QUAD)
	_centered_text(font, fs_small, origin + Vector2(side * 0.75, side * 0.75), "OBSESSIVE", COLOR_QUAD)


	_centered_text(font, fs, Vector2(center.x, origin.y - MARGIN_TB * 0.5), "INDIFFERENT", COLOR_AXISLABEL)
	_centered_text(font, fs, Vector2(center.x, origin.y + side + MARGIN_TB * 0.5), "CURIOUS", COLOR_AXISLABEL)
	_text_right_of(font, fs, Vector2(origin.x + side + 8.0, center.y), "CONTEMPTUOUS", COLOR_AXISLABEL)
	_text_left_of(font, fs, Vector2(origin.x - 8.0, center.y), "RESPECTFUL", COLOR_AXISLABEL)

	var eff: = half - (MARKER_RADIUS + 4.0)



	var ip: = center + Vector2(idimya_unit.x * half, idimya_unit.y * half)
	_marker(ip, COLOR_IDIMYA)


	if _has_player:
		var pu: = cr_to_unit(_player_c, _player_r, c_min, c_max, r_min, r_max)
		var pp: = center + Vector2(pu.x * eff, pu.y * eff)
		_marker(pp, COLOR_YOU)

func _marker(p: Vector2, col: Color) -> void :
	draw_circle(p, MARKER_RADIUS + 2.0, Color(0.05, 0.05, 0.08, 0.9))
	draw_circle(p, MARKER_RADIUS, col)

func _centered_text(font: Font, fs: int, at: Vector2, s: String, col: Color) -> void :
	var w: = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(at.x - w / 2.0, at.y + fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _text_right_of(font: Font, fs: int, at: Vector2, s: String, col: Color) -> void :
	draw_string(font, Vector2(at.x, at.y + fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _text_left_of(font: Font, fs: int, at: Vector2, s: String, col: Color) -> void :
	var w: = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(at.x - w, at.y + fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
