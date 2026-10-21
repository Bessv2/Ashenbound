extends "res://tests/framework/test_case.gd"
## Tests for TouchActionButton, alone and together with the joystick.

const BUTTON_POSITION := Vector2(1000, 450)
const BUTTON_SIZE := Vector2(220, 220)
const CENTER := BUTTON_POSITION + BUTTON_SIZE * 0.5
const STICK_START := Vector2(280, 510)

var button: TouchActionButton
var joystick: TouchJoystick


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	button = TouchActionButton.new()
	button.position = BUTTON_POSITION
	button.size = BUTTON_SIZE
	layer.add_child(button)
	joystick = TouchJoystick.new()
	joystick.position = Vector2(0, 300)
	joystick.size = Vector2(560, 420)
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


func _attack_held() -> bool:
	return Input.is_action_pressed(GameplayActions.ATTACK)


func test_touch_holds_the_action_until_released() -> void:
	_touch(0, CENTER, true)
	check(button.is_pressed() and _attack_held(), "touch should hold the action")
	_touch(0, CENTER, false)
	check(not button.is_pressed() and not _attack_held(), "release should let go")


func test_corners_outside_the_circle_do_not_count() -> void:
	_touch(0, BUTTON_POSITION + Vector2(5, 5), true)
	check(not _attack_held(), "the square's corner is outside the round button")
	_touch(0, BUTTON_POSITION + Vector2(5, 5), false)


func test_second_finger_is_ignored() -> void:
	_touch(0, CENTER, true)
	_touch(1, CENTER + Vector2(20, 0), true)
	_touch(1, CENTER + Vector2(20, 0), false)
	check(_attack_held(), "lifting another finger must not release the button")
	_touch(0, CENTER, false)
	check(not _attack_held(), "lifting the owning finger releases it")


func test_works_together_with_the_joystick() -> void:
	_touch(0, STICK_START, true)
	_drag(0, STICK_START + Vector2(joystick.radius, 0))
	_touch(1, CENTER, true)
	check(_attack_held(), "attack held by the second finger")
	check_vector_near(MovementInput.get_vector(), Vector2(1, 0), 0.001, "stick still steering")
	_touch(1, CENTER, false)
	check(not _attack_held(), "attack released")
	check_vector_near(MovementInput.get_vector(), Vector2(1, 0), 0.001, "stick unaffected by the button")
	_touch(0, STICK_START + Vector2(joystick.radius, 0), false)


func test_pausing_releases_the_button() -> void:
	_touch(0, CENTER, true)
	get_tree().paused = true
	check(not button.is_pressed() and not _attack_held(), "pause should release the button")
	get_tree().paused = false
	_touch(0, CENTER, true)
	check(button.is_pressed(), "a new touch works after resuming")
	_touch(0, CENTER, false)


func test_focus_loss_releases_the_button() -> void:
	_touch(0, CENTER, true)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not button.is_pressed() and not _attack_held(), "focus loss should release the button")
