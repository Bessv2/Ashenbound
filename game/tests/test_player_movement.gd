extends "res://tests/framework/test_case.gd"
## Integration tests: the real main scene, physics and camera.
## Inner faces of the arena walls, minus the player capsule radius.
const ARENA_LIMIT := 20.0 - 0.4

var main: Node3D
var player: PlayerController
var rig: IsometricCameraRig


func _ready() -> void:
	main = instantiate_main()
	add_child(main)
	player = main.get_node("Player")
	rig = main.get_node("CameraRig")


func _respawn() -> void:
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	rig.snap_to_target()
	await wait_physics_frames(2)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func test_player_settles_on_the_floor() -> void:
	await wait_physics_frames(30)
	check(player.is_on_floor(), "player should be on the floor")
	check_near(player.global_position.y, 0.0, 0.05, "player height")


func test_keyboard_moves_relative_to_camera() -> void:
	await _respawn()
	Input.action_press(MovementInput.FORWARD)
	await wait_physics_frames(30)
	MovementInput.release_all()
	var moved := _flat(player.global_position).normalized()
	var camera_forward := _flat(-rig.camera.global_basis.z).normalized()
	check(moved.dot(camera_forward) > 0.999, "forward should move away from the camera, moved %s" % moved)


func test_player_cannot_leave_the_arena() -> void:
	for action in MovementInput.ACTIONS:
		await _respawn()
		Input.action_press(action)
		await wait_physics_frames(60 * 7)
		MovementInput.release_all()
		var position := player.global_position
		check(absf(position.x) <= ARENA_LIMIT + 0.05 and absf(position.z) <= ARENA_LIMIT + 0.05,
				"%s: player escaped the arena at %s" % [action, position])
		check(_flat(position).length() > 15.0, "%s: player should have reached a wall, at %s" % [action, position])
		check_near(position.y, 0.0, 0.05, "%s: player should stay on the floor" % action)


func test_movement_is_frame_rate_independent() -> void:
	var distances: Array[float] = []
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		await _respawn()
		var start := player.global_position
		Input.action_press(MovementInput.RIGHT)
		await wait_physics_frames(ticks)  # One simulated second.
		MovementInput.release_all()
		distances.append(_flat(player.global_position - start).length())
	Engine.physics_ticks_per_second = 60
	for distance in distances:
		check_near(distance, distances[1], distances[1] * 0.02,
				"distance per second should match across tick rates %s" % [distances])
	# 6 m/s top speed minus the short acceleration ramp.
	check_near(distances[1], 5.7, 0.1, "distance covered in one second")


func test_releasing_input_stops_cleanly() -> void:
	await _respawn()
	Input.action_press(MovementInput.LEFT)
	await wait_physics_frames(60)
	MovementInput.release_all()
	await wait_physics_frames(15)
	check(_flat(player.velocity).is_zero_approx(), "velocity should reach zero, got %s" % player.velocity)
	var stopped_at := player.global_position
	await wait_physics_frames(30)
	check_vector_near(player.global_position, stopped_at, 0.0001, "player should not drift after stopping")


func test_camera_follows_without_rotating() -> void:
	await _respawn()
	var initial_basis := rig.camera.global_basis
	Input.action_press(MovementInput.RIGHT)
	await wait_physics_frames(90)
	MovementInput.release_all()
	Input.action_press(MovementInput.BACK)
	await wait_physics_frames(90)
	MovementInput.release_all()
	check(rig.camera.global_basis.is_equal_approx(initial_basis), "camera must not rotate")
	await wait_physics_frames(120)
	check_vector_near(rig.global_position, player.global_position + rig.target_offset, 0.05,
			"camera should settle on the player")


func test_camera_is_orthographic_and_isometric() -> void:
	check(rig.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "camera should be orthographic")
	var euler := rig.global_basis.get_euler()
	check_near(rad_to_deg(euler.x), IsometricCameraRig.ISOMETRIC_PITCH_DEGREES, 0.01, "pitch")
	check_near(rad_to_deg(euler.y), 45.0, 0.01, "yaw")
	check(rig.camera.current, "rig camera should be the active camera")
