extends "res://tests/framework/test_case.gd"
## Unit tests for MovementInput: one vector for keys and joystick, and the
## camera-relative conversion to a ground direction.


func _iso_basis(pitch_degrees: float = IsometricCameraRig.ISOMETRIC_PITCH_DEGREES) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), deg_to_rad(45.0), 0.0))


func test_no_input_is_zero() -> void:
	check(MovementInput.get_vector() == Vector2.ZERO, "idle input should be zero")


func test_single_key_is_full_strength() -> void:
	Input.action_press(MovementInput.RIGHT)
	check_vector_near(MovementInput.get_vector(), Vector2(1, 0), 0.0001, "right")


func test_diagonal_keys_are_normalized() -> void:
	Input.action_press(MovementInput.RIGHT)
	Input.action_press(MovementInput.FORWARD)
	var intent := MovementInput.get_vector()
	check_near(intent.length(), 1.0, 0.0001, "diagonal length")
	check_vector_near(intent, Vector2(1, -1).normalized(), 0.0001, "diagonal direction")


func test_partial_strength_is_preserved() -> void:
	Input.action_press(MovementInput.LEFT, 0.3)
	check_vector_near(MovementInput.get_vector(), Vector2(-0.3, 0), 0.0001, "analog strength")


func test_opposite_keys_cancel() -> void:
	Input.action_press(MovementInput.LEFT)
	Input.action_press(MovementInput.RIGHT)
	check(MovementInput.get_vector() == Vector2.ZERO, "left + right should cancel")


func test_release_all_clears_every_action() -> void:
	for action in MovementInput.ACTIONS:
		Input.action_press(action)
	MovementInput.release_all()
	for action in MovementInput.ACTIONS:
		check(not Input.is_action_pressed(action), "%s still pressed" % action)


func test_world_direction_is_flat_and_keeps_length() -> void:
	var basis := _iso_basis()
	for degrees in range(0, 360, 45):
		var intent := Vector2.from_angle(deg_to_rad(degrees))
		var direction := MovementInput.to_world_direction(intent, basis)
		check_near(direction.y, 0.0, 0.0001, "y at %d°" % degrees)
		check_near(direction.length(), 1.0, 0.0001, "length at %d°" % degrees)
	var half := MovementInput.to_world_direction(Vector2(0.5, 0), basis)
	check_near(half.length(), 0.5, 0.0001, "partial input keeps its length")


func test_forward_moves_away_from_camera() -> void:
	# The rig yaws 45°, so the camera sits toward +X/+Z and looks toward -X/-Z.
	var forward := MovementInput.to_world_direction(Vector2(0, -1), _iso_basis())
	check_vector_near(forward, Vector3(-1, 0, -1).normalized(), 0.0001, "forward")


func test_right_is_screen_right() -> void:
	var right := MovementInput.to_world_direction(Vector2(1, 0), _iso_basis())
	check_vector_near(right, Vector3(1, 0, -1).normalized(), 0.0001, "right")


func test_world_direction_ignores_camera_pitch() -> void:
	var intent := Vector2(0.6, -0.8)
	var shallow := MovementInput.to_world_direction(intent, _iso_basis(-20.0))
	var steep := MovementInput.to_world_direction(intent, _iso_basis(-70.0))
	check_vector_near(shallow, steep, 0.0001, "pitch should not change direction")
