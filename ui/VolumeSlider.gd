extends Control






const BAR_W: = 340.0
const H: = 26.0
const KNOB: = 16.0
const TRACK_H: = 6.0

const COL_FILL: = Color("e7e1d6")
const COL_TRACK: = Color(0.32, 0.31, 0.29, 1.0)

var value: float = 1.0

func _ready() -> void :
	custom_minimum_size = Vector2(BAR_W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_value(v: float) -> void :
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func value_from_global_x(gx: float) -> float:
	var left: = global_position.x + KNOB / 2.0
	var right: = global_position.x + size.x - KNOB / 2.0
	return clampf((gx - left) / maxf(1.0, right - left), 0.0, 1.0)

func _draw() -> void :
	var cy: = size.y / 2.0
	var left: = KNOB / 2.0
	var span: = size.x - KNOB
	var ty: = cy - TRACK_H / 2.0

	draw_rect(Rect2(left, ty, span, TRACK_H), COL_TRACK)
	draw_rect(Rect2(left, ty, value * span, TRACK_H), COL_FILL)

	var kx: = left + value * span
	draw_rect(Rect2(kx - KNOB / 2.0, cy - KNOB / 2.0, KNOB, KNOB), COL_FILL)
