class_name Banner
extends Control
## A big title across the upper middle of the screen that sweeps in, holds and
## fades: a room's name on entering it, a boss waking, a level gained. One at
## a time; a new one replaces the one shown. Never blocks input.

const HOLD_SECONDS := 1.6

var _title: Label
var _subtitle: Label
var _line_left: ColorRect
var _line_right: ColorRect
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_top = 150.0
	offset_left = -420.0
	offset_right = 420.0
	offset_bottom = 290.0
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 18)
	column.add_child(row)
	_line_left = _line()
	row.add_child(_line_left)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 54)
	_title.add_theme_constant_override(&"outline_size", 14)
	_title.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_title)
	_line_right = _line()
	row.add_child(_line_right)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override(&"font_size", 26)
	_subtitle.add_theme_constant_override(&"outline_size", 8)
	_subtitle.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	hide()


## The title shown now, or "" when no banner is up.
func current_title() -> String:
	return _title.text if visible else ""


## Shows `title` (and `subtitle` under it) in `color`.
func show_banner(title: String, subtitle: String = "", color: Color = Color("#E8D9C0")) -> void:
	_title.text = title.to_upper()
	_title.modulate = color
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	_subtitle.modulate = Color(0.86, 0.8, 0.72)
	_line_left.color = color
	_line_right.color = color
	show()
	if _tween:
		_tween.kill()
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(1.25, 1.25)
	_line_left.custom_minimum_size.x = 0.0
	_line_right.custom_minimum_size.x = 0.0
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_line_left, "custom_minimum_size:x", 90.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_line_right, "custom_minimum_size:x", 90.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(HOLD_SECONDS)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.6)
	_tween.chain().tween_callback(hide)


func _line() -> ColorRect:
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line
