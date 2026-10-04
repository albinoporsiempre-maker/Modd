extends RefCounted
class_name UIStyle











const FONT_BODY_FILE: = preload("res://assets/fonts/ArchivoNarrow.ttf")
const FONT_BOLD_FILE: = preload("res://assets/fonts/Arimo.ttf")


const TEXT_PRIMARY: = Color("e7e1d6")
const TEXT_SECONDARY: = Color("b8b1a7")
const RULE: = Color("8f887f")
const X_COLOR: = Color("e7e1d6")
const X_CYAN: = Color(0.38, 0.8, 0.86)
const VERDICT_COLOR: = Color("e7e1d6")


const SIZE_DIALOGUE: = 18
const SIZE_SPEAKER: = 26
const SIZE_CHOICE: = 18
const SIZE_PROSE: = 18
const SIZE_SUBLABEL: = 16
const SIZE_CLASS: = 36
const SIZE_VERDICT: = 56


const DIALOGUE_MAX_WIDTH: = 760.0
const DIALOGUE_TOP_IDIMYA: = 560.0
const DIALOGUE_TOP_YOU: = 636.0
const CHOICE_SPACING: = 10


const TYPE_CPS: = 30.0
const TYPE_DOT_MULT: = 6.0
const TYPE_PUNCT_MULT: = 3.0



const SHADOW_COLOR: = Color(0.0, 0.0, 0.0, 0.85)
const SHADOW_SIZE: = 5


const BOX_SIZE: = 22.0
const BOX_STROKE: = 2.0
const X_STROKE: = 2.5
const BOX_GAP: = 14.0
const RULE_THICKNESS: = 1.0

const TAG_WGHT: = 2003265652

static var _bold: FontVariation
static var _ending_tex: GradientTexture2D




static func ending_stylebox() -> StyleBoxTexture:
	if _ending_tex == null:
		var grad: = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		grad.colors = PackedColorArray([Color(0.02, 0.02, 0.02, 0.22), Color(0.01, 0.01, 0.01, 0.86)])
		_ending_tex = GradientTexture2D.new()
		_ending_tex.gradient = grad
		_ending_tex.width = 8
		_ending_tex.height = 256
		_ending_tex.fill_from = Vector2(0.5, 0.0)
		_ending_tex.fill_to = Vector2(0.5, 1.0)
	var sb: = StyleBoxTexture.new()
	sb.texture = _ending_tex
	return sb

static func font_bold() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = FONT_BOLD_FILE
		_bold.variation_opentype = {TAG_WGHT: 700.0}
	return _bold

static func font_body() -> FontFile:
	return FONT_BODY_FILE




static func shadow(c: Control) -> void :
	c.add_theme_color_override("font_outline_color", SHADOW_COLOR)
	c.add_theme_constant_override("outline_size", SHADOW_SIZE)

static func label_body(l: Label, size: int = SIZE_DIALOGUE, col: Color = TEXT_PRIMARY) -> void :
	l.add_theme_font_override("font", FONT_BODY_FILE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	shadow(l)

static func label_bold(l: Label, size: int, col: Color = TEXT_PRIMARY) -> void :
	l.add_theme_font_override("font", font_bold())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	shadow(l)

static func rich_body(r: RichTextLabel, size: int = SIZE_PROSE, col: Color = TEXT_PRIMARY) -> void :
	r.add_theme_font_override("normal_font", FONT_BODY_FILE)
	r.add_theme_font_override("bold_font", font_bold())
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", col)
	shadow(r)
