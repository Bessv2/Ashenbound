class_name TouchActionButton
extends Control
## A round on-screen button that holds an InputMap action while touched.
## Optionally shows a cooldown as a dark sweep over its face.
##
## Like TouchJoystick, it tracks a single finger by touch index, so it works
## while another finger is on the stick. It only releases the action if it
## pressed it, so it never cancels a key held on its own. It resets on pause,
## focus loss and when hidden, because a release that happens then never
## arrives.

const NO_TOUCH := -1

@export var action: StringName = GameplayActions.ATTACK
@export var label: String = "ATTACK"

@export_group("Appearance")
@export var fill_color: Color = Color(0.09, 0.07, 0.09, 0.6)
@export var ring_color: Color = Color(0.5, 0.25, 0.13, 0.9)
@export var pressed_color: Color = Color(0.95, 0.45, 0.2, 0.85)
@export var text_color: Color = Color(0.86, 0.8, 0.72, 1.0)
@export var cooldown_color: Color = Color(0.0, 0.0, 0.0, 0.55)

## Optional. Returns the share of a cooldown still to run, from 1 (just
## started) to 0 (ready). While above zero, that share of the face is dimmed,
## clockwise from the top. The button still presses during a cooldown: what
## the action does then is up to the game.
var cooldown: Callable

var _touch_index: int = NO_TOUCH
var _shown_cooldown: float = 0.0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE:
			reset()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				reset()
		NOTIFICATION_RESIZED:
			queue_redraw()


func _process(_delta: float) -> void:
	var fraction := cooldown_fraction()
	if fraction != _shown_cooldown:
		_shown_cooldown = fraction
		queue_redraw()


## The cooldown share currently shown, or 0 without a cooldown.
func cooldown_fraction() -> float:
	return clampf(cooldown.call(), 0.0, 1.0) if cooldown.is_valid() else 0.0


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= _radius()


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed and not is_pressed():
		_touch_index = touch.index
		Input.action_press(action)
		queue_redraw()
		accept_event()
	elif not touch.pressed and touch.index == _touch_index:
		reset()
		accept_event()


func is_pressed() -> bool:
	return _touch_index != NO_TOUCH


## Lets go of the button, releasing the action if this button pressed it.
func reset() -> void:
	if is_pressed():
		Input.action_release(action)
	_touch_index = NO_TOUCH
	queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) * 0.5


func _draw() -> void:
	var center := size * 0.5
	var radius := _radius()
	draw_circle(center, radius, pressed_color if is_pressed() else fill_color, true, -1.0, true)
	# Thinner slivers are invisible and can fail to triangulate.
	if _shown_cooldown >= 0.01:
		_draw_sector(center, radius, _shown_cooldown, cooldown_color)
	draw_arc(center, radius - 1.5, 0.0, TAU, 64, ring_color, 3.0, true)
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.35),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


## Fills `fraction` of the circle, clockwise from the top.
func _draw_sector(center: Vector2, radius: float, fraction: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	var segments := maxi(2, ceili(64.0 * fraction))
	var start := -PI * 0.5
	for i in segments + 1:
		var angle := start + TAU * fraction * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
