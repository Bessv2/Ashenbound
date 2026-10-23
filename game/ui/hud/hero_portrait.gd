class_name HeroPortrait
extends Control
## The hero's round portrait at the top left: the class's weapon on a dark
## disc, ringed in the class's colour, with the level in a badge below.

var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
var accent: Color = Color("#DB6028"):
	set(value):
		accent = value
		queue_redraw()
var level: int = 1:
	set(value):
		level = value
		queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(centre, radius, Color(0.1, 0.08, 0.09, 0.92), true, -1.0, true)
	draw_circle(centre, radius * 0.82, Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.9), true, -1.0, true)
	if icon:
		var side := radius * 1.25
		draw_texture_rect(icon, Rect2(centre - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color(0.95, 0.9, 0.82))
	draw_arc(centre, radius, 0.0, TAU, 64, accent, 4.0, true)
	draw_arc(centre, radius + 2.5, 0.0, TAU, 64, Color(0, 0, 0, 0.6), 1.5, true)
	# The level badge, overlapping the bottom of the ring.
	var font := get_theme_default_font()
	var font_size := 20
	var text := str(level)
	var badge := centre + Vector2(0, radius * 0.92)
	draw_circle(badge, 15.0, Color(0.08, 0.06, 0.07, 0.97), true, -1.0, true)
	draw_arc(badge, 15.0, 0.0, TAU, 32, Color("#D9A44C"), 2.0, true)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, badge + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.36),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#E2CBB4"))
