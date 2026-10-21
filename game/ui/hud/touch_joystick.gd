class_name TouchJoystick
extends Control
## On-screen movement stick for touch screens.
##
## Touching anywhere inside this control places the stick under that finger,
## and only that finger moves it, so other fingers stay free for buttons.
## Touches arrive through GUI routing, which tracks each finger separately and
## respects controls drawn on top. The output is written to InputMap actions,
## the same ones the keyboard drives, which keeps gameplay code unaware of the
## HUD.
##
## Why not Godot's built-in VirtualJoystick (4.7): it has no way to reset it
## when a finger is lifted while the game is paused or in the background (the
## release never reaches a paused control), and it releases actions it did not
## press, cancelling held keys. This control resets on pause and focus loss,
## and only ever releases the actions it pressed itself.

## Emitted when the stick output changes. +x is right, +y is down. Length 0..1.
signal output_changed(output: Vector2)

const NO_TOUCH := -1

@export var action_left: StringName = MovementInput.LEFT
@export var action_right: StringName = MovementInput.RIGHT
@export var action_up: StringName = MovementInput.FORWARD
@export var action_down: StringName = MovementInput.BACK

## Radius of the base ring in pixels. Full deflection is reached at the rim.
@export_range(32.0, 256.0, 1.0, "suffix:px") var radius: float = 110.0
## Fraction of the radius around the center that produces no output.
@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.15
## Scales deflection. Above 1 reaches full output before the rim.
@export_range(0.5, 2.0, 0.05) var sensitivity: float = 1.0

@export_group("Appearance")
@export_range(16.0, 128.0, 1.0, "suffix:px") var knob_radius: float = 46.0
## Gap between the resting stick and the control's bottom-left corner.
@export_range(0.0, 200.0, 1.0, "suffix:px") var rest_margin: float = 56.0
@export var base_color: Color = Color(0.0, 0.0, 0.0, 0.3)
@export var ring_color: Color = Color(0.85, 0.8, 0.72, 0.35)
@export var knob_color: Color = Color(0.85, 0.8, 0.72, 0.5)
@export var active_color: Color = Color(0.95, 0.45, 0.2, 0.85)

## Current output. Read-only; set by touch input.
var output: Vector2 = Vector2.ZERO

var _touch_index: int = NO_TOUCH
var _base_center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO
var _driven_actions: Dictionary[StringName, bool] = {}


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE:
			reset()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				reset()
		NOTIFICATION_RESIZED:
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


## Whether a finger currently controls the stick.
func is_active() -> bool:
	return _touch_index != NO_TOUCH


## Lets go of the stick and releases every action it is holding.
func reset() -> void:
	_touch_index = NO_TOUCH
	_knob_offset = Vector2.ZERO
	_set_output(Vector2.ZERO)
	queue_redraw()


## Maps raw deflection (length 0..1) to output: values inside the dead zone
## become zero, the remainder is rescaled to start at zero, multiplied by
## sensitivity and capped at 1. Direction is preserved.
static func shape_output(raw: Vector2, dead_zone_ratio: float, sensitivity_scale: float) -> Vector2:
	var length := raw.length()
	if length <= dead_zone_ratio:
		return Vector2.ZERO
	var strength := (length - dead_zone_ratio) / (1.0 - dead_zone_ratio) * sensitivity_scale
	return raw / length * minf(strength, 1.0)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if is_active():
			return
		_touch_index = event.index
		_base_center = _clamp_center(event.position)
		_move_knob_to(event.position)
		accept_event()
	elif event.index == _touch_index:
		reset()
		accept_event()


func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	_move_knob_to(event.position)
	accept_event()


func _move_knob_to(local_position: Vector2) -> void:
	_knob_offset = (local_position - _base_center).limit_length(radius)
	_set_output(shape_output(_knob_offset / radius, dead_zone, sensitivity))
	queue_redraw()


func _set_output(value: Vector2) -> void:
	if value == output:
		return
	output = value
	_drive(action_left, -value.x)
	_drive(action_right, value.x)
	_drive(action_up, -value.y)
	_drive(action_down, value.y)
	output_changed.emit(value)


func _drive(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_driven_actions[action] = true
	elif _driven_actions.has(action):
		Input.action_release(action)
		_driven_actions.erase(action)


## Keeps the whole base ring inside the control.
func _clamp_center(point: Vector2) -> Vector2:
	return Vector2(
			clampf(point.x, radius, maxf(radius, size.x - radius)),
			clampf(point.y, radius, maxf(radius, size.y - radius)))


func _draw() -> void:
	var center := _base_center if is_active() else _clamp_center(
			Vector2(rest_margin + radius, size.y - rest_margin - radius))
	var accent := active_color if is_active() else ring_color
	draw_circle(center, radius, base_color, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 64, accent, 3.0, true)
	draw_circle(center + _knob_offset, knob_radius, active_color if is_active() else knob_color, true, -1.0, true)
