extends "res://tests/framework/test_case.gd"
## Tests for TouchJoystick, driven by screen touch events pushed through the
## root viewport so they take the same GUI routing path as real touches.

const ZONE_POSITION := Vector2(0, 300)
const ZONE_SIZE := Vector2(560, 420)
const START := Vector2(280, 510)

var joystick: TouchJoystick


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	joystick = TouchJoystick.new()
	joystick.position = ZONE_POSITION
	joystick.size = ZONE_SIZE
	joystick.dead_zone = 0.15
	joystick.sensitivity = 1.0
	layer.add_child(joystick)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	get_viewport().push_input(event)


func _drag(index: int, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	get_viewport().push_input(event)


func _no_movement_pressed() -> bool:
	for action in MovementInput.ACTIONS:
		if Input.is_action_pressed(action):
			return false
	return true


func test_shape_output_applies_dead_zone_and_sensitivity() -> void:
	check(TouchJoystick.shape_output(Vector2(0.1, 0), 0.15, 1.0) == Vector2.ZERO, "inside dead zone")
	check_vector_near(TouchJoystick.shape_output(Vector2(1, 0), 0.15, 1.0), Vector2(1, 0), 0.0001, "rim")
	check_vector_near(TouchJoystick.shape_output(Vector2(0, 0.575), 0.15, 1.0), Vector2(0, 0.5), 0.0001, "halfway")
	check_vector_near(TouchJoystick.shape_output(Vector2(0, 0.575), 0.15, 2.0), Vector2(0, 1), 0.0001, "sensitivity")


func test_drag_drives_movement_actions() -> void:
	_touch(0, START, true)
	check(joystick.is_active(), "touch inside the zone should capture the stick")
	check(MovementInput.get_vector() == Vector2.ZERO, "touch without drag should not move")
	_drag(0, START + Vector2(joystick.radius, 0))
	check_vector_near(MovementInput.get_vector(), Vector2(1, 0), 0.001, "drag right")
	_drag(0, START + Vector2(0, -3 * joystick.radius))
	check_vector_near(MovementInput.get_vector(), Vector2(0, -1), 0.001, "drag past rim is clamped")


func test_release_stops_cleanly() -> void:
	_touch(0, START, true)
	_drag(0, START + Vector2(joystick.radius, joystick.radius))
	_touch(0, START + Vector2(joystick.radius, joystick.radius), false)
	check(not joystick.is_active(), "stick should be released")
	check(joystick.output == Vector2.ZERO, "output should be zero")
	check(_no_movement_pressed(), "no movement action should stay pressed")


func test_second_finger_is_ignored() -> void:
	_touch(0, START, true)
	_drag(0, START + Vector2(joystick.radius, 0))
	_touch(1, START + Vector2(-40, 0), true)
	_drag(1, START + Vector2(-joystick.radius, 0))
	check_vector_near(MovementInput.get_vector(), Vector2(1, 0), 0.001, "second finger must not steer")
	_touch(1, START + Vector2(-joystick.radius, 0), false)
	check(joystick.is_active(), "lifting the second finger must not release the stick")
	_touch(0, START + Vector2(joystick.radius, 0), false)
	check(_no_movement_pressed(), "lifting the first finger releases the stick")


func test_touch_outside_the_zone_is_ignored() -> void:
	_touch(0, Vector2(1000, 120), true)
	check(not joystick.is_active(), "touch outside the zone should not capture the stick")
	_touch(0, Vector2(1000, 120), false)


func test_does_not_cancel_a_held_key() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await wait_process_frames(1)
	check(Input.is_action_pressed(MovementInput.RIGHT), "D should press move_right")
	_touch(0, START, true)
	_drag(0, START + Vector2(0, -joystick.radius))
	_touch(0, START + Vector2(0, -joystick.radius), false)
	check(Input.is_action_pressed(MovementInput.RIGHT), "releasing the stick must not release a held key")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await wait_process_frames(1)


func test_pausing_resets_the_stick() -> void:
	_touch(0, START, true)
	_drag(0, START + Vector2(joystick.radius, 0))
	get_tree().paused = true
	check(not joystick.is_active(), "pause should release the stick")
	check(_no_movement_pressed(), "pause should release movement actions")
	get_tree().paused = false
	# The finger was lifted while paused, so its release never arrived. A new
	# touch must still be accepted.
	_touch(0, START, true)
	check(joystick.is_active(), "a new touch should work after resuming")
	_touch(0, START, false)


func test_focus_loss_resets_the_stick() -> void:
	_touch(0, START, true)
	_drag(0, START + Vector2(0, joystick.radius))
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not joystick.is_active(), "focus loss should release the stick")
	check(_no_movement_pressed(), "focus loss should release movement actions")
