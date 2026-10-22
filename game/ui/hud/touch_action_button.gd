class_name TouchActionButton
extends Control
## A round on-screen button that holds an InputMap action while touched.
## Optionally shows a cooldown as a dark sweep over its face, and flashes a
## ring when the cooldown ends. Sinks a little while pressed.
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
## Optional: returns the badge text, polled every frame (souls held).
var badge_source: Callable
## Optional: a short text in a disc at the top right (a potion count).
var badge: String = "":
	set(value):
		badge = value
		queue_redraw()

var _touch_index: int = NO_TOUCH
var _shown_cooldown: float = 0.0
## 1 right when the cooldown ended, fading to 0: the "ready" ring.
var _ready_flash: float = 0.0
## 0 to 1: how far the face has sunk under a finger.
var _press: float = 0.0


## Takes `color` for the ring, the pressed face and the ready flash.
func set_accent(color: Color) -> void:
	ring_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.95)
	pressed_color = Color(color.r, color.g, color.b, 0.85)
	queue_redraw()


## Whether the "ready" ring is showing.
func is_flashing_ready() -> bool:
	return _ready_flash > 0.0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE:
			reset()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				reset()
		NOTIFICATION_RESIZED:
			queue_redraw()


func _process(delta: float) -> void:
	if badge_source.is_valid():
		var text: String = badge_source.call()
		if text != badge:
			badge = text
	var fraction := cooldown_fraction()
	if fraction != _shown_cooldown:
		if fraction <= 0.0 and _shown_cooldown > 0.0:
			_ready_flash = 1.0
		_shown_cooldown = fraction
		queue_redraw()
	if _ready_flash > 0.0:
		_ready_flash = maxf(_ready_flash - delta * 2.2, 0.0)
		queue_redraw()
	var target := 1.0 if is_pressed() else 0.0
	if _press != target:
		_press = move_toward(_press, target, delta * 14.0)
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
	var radius := _radius() * (1.0 - 0.07 * _press)
	draw_circle(center, radius, fill_color.lerp(pressed_color, _press), true, -1.0, true)
	# Thinner slivers are invisible and can fail to triangulate.
	if _shown_cooldown >= 0.01:
		_draw_sector(center, radius, _shown_cooldown, cooldown_color)
	draw_arc(center, radius - 1.5, 0.0, TAU, 64, ring_color, 3.0, true)
	if _ready_flash > 0.0:
		# A bright ring that swells out of the button and fades: ready again.
		var glow := Color(pressed_color.r, pressed_color.g, pressed_color.b, _ready_flash)
		draw_arc(center, radius - 1.5 + (1.0 - _ready_flash) * 10.0, 0.0, TAU, 64, glow, 2.0 + 5.0 * _ready_flash, true)
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.35),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if badge != "":
		var spot := center + Vector2(radius * 0.72, -radius * 0.72)
		draw_circle(spot, 17.0, Color(0.06, 0.04, 0.05, 0.95), true, -1.0, true)
		draw_arc(spot, 16.0, 0.0, TAU, 32, ring_color, 2.0, true)
		var badge_size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, spot + Vector2(-badge_size.x * 0.5, font.get_ascent(font_size) * 0.35),
				badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


## Fills `fraction` of the circle, clockwise from the top.
func _draw_sector(center: Vector2, radius: float, fraction: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	var segments := maxi(2, ceili(64.0 * fraction))
	var start := -PI * 0.5
	for i in segments + 1:
		var angle := start + TAU * fraction * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
