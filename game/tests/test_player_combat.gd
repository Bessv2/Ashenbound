extends "res://tests/framework/test_case.gd"
## Integration tests: the player's attack and the training dummies in the
## real main scene.

const MainScene := preload("res://scenes/main.tscn")

var main: Node3D
var player: PlayerController
var dummy: TrainingDummy


func _ready() -> void:
	main = MainScene.instantiate()
	add_child(main)
	player = main.get_node("Player")
	dummy = main.get_node("Enemies/TrainingDummyEast")


## Puts the player `distance` meters west of the east dummy, at rest.
func _stand_near_dummy(distance: float) -> void:
	await _stand_at(dummy.global_position - Vector3(distance, 0, 0))


## An open spot more than 7 m from every dummy, beyond aim-assist range.
func _stand_in_the_open() -> void:
	await _stand_at(Vector3(0, 0, 5))


func _stand_at(position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await wait_physics_frames(2)


func test_attack_damages_a_dummy_in_reach() -> void:
	await _stand_near_dummy(1.5)
	Input.action_press(GameplayActions.ATTACK)
	await wait_physics_frames(15)  # Longer than the windup, shorter than one attack.
	Input.action_release(GameplayActions.ATTACK)
	check(dummy.health.current == 40, "one hit for 10, health %d" % dummy.health.current)


func test_attack_turns_the_player_toward_the_target() -> void:
	await _stand_near_dummy(1.5)
	Input.action_press(GameplayActions.ATTACK)
	await wait_physics_frames(2)
	Input.action_release(GameplayActions.ATTACK)
	var visual: Node3D = player.get_node("Visual")
	var facing := -visual.global_basis.z
	check(facing.dot(Vector3.RIGHT) > 0.999, "player should face the dummy, faces %s" % facing)


func test_attack_rate_is_frame_rate_independent() -> void:
	var counts: Array[int] = []
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		await _stand_in_the_open()
		var attack: MeleeAttack = player.get_node("MeleeAttack")
		var swings := [0]
		var on_started := func(_direction: Vector3) -> void: swings[0] += 1
		attack.started.connect(on_started)
		Input.action_press(GameplayActions.ATTACK)
		await wait_physics_frames(ticks * 2)  # Two simulated seconds.
		Input.action_release(GameplayActions.ATTACK)
		attack.started.disconnect(on_started)
		counts.append(swings[0])
		await wait_physics_frames(ticks)  # Let the last attack finish.
	Engine.physics_ticks_per_second = 60
	# 0.45 s per attack: swings start at 0, 0.45, 0.9, 1.35 and 1.8 s.
	check(counts == [5, 5, 5], "swings in 2 s at 30/60/120 Hz: %s" % [counts])


func test_attacking_slows_movement() -> void:
	await _stand_in_the_open()
	var start := player.global_position
	Input.action_press(MovementInput.BACK)
	await wait_physics_frames(30)
	var free_distance := player.global_position.distance_to(start)
	MovementInput.release_all()
	await _stand_in_the_open()
	start = player.global_position
	Input.action_press(MovementInput.BACK)
	Input.action_press(GameplayActions.ATTACK)
	await wait_physics_frames(30)
	var attacking_distance := player.global_position.distance_to(start)
	check(attacking_distance < free_distance * 0.5,
			"attacking should slow movement: %.2f m vs %.2f m" % [attacking_distance, free_distance])
	check(attacking_distance > 0.0, "the player can still move while attacking")


func test_pause_freezes_an_attack_in_progress() -> void:
	await _stand_near_dummy(1.5)
	var pause_controller: PauseController = main.get_node("PauseController")
	Input.action_press(GameplayActions.ATTACK)
	await wait_physics_frames(2)
	pause_controller.set_paused(true)
	check(not Input.is_action_pressed(GameplayActions.ATTACK), "pause releases the attack action")
	await wait_physics_frames(30)
	check(dummy.health.current == 50, "no hit lands while paused")
	pause_controller.set_paused(false)
	await wait_physics_frames(10)
	check(dummy.health.current == 40, "the attack finishes after resuming")


func test_dummy_dies_and_respawns() -> void:
	dummy.health.apply_damage(dummy.health.max_health)
	await wait_physics_frames(2)
	var collision: CollisionShape3D = dummy.get_node("CollisionShape3D")
	var visual: Node3D = dummy.get_node("Visual")
	check(collision.disabled and not visual.visible, "a destroyed dummy is hidden and not solid")
	await wait_physics_frames(int(dummy.respawn_delay * 60) + 2)
	check(dummy.health.current == dummy.health.max_health, "respawns with full health")
	check(not collision.disabled and visual.visible, "a respawned dummy is visible and solid")


func test_player_cannot_walk_through_a_dummy() -> void:
	await _stand_near_dummy(3.0)
	# World +X is screen right-down: right (+x, -z) plus back (+x, +z).
	Input.action_press(MovementInput.RIGHT)
	Input.action_press(MovementInput.BACK)
	await wait_physics_frames(90)
	MovementInput.release_all()
	check(player.global_position.x < dummy.global_position.x - 0.8,
			"player should stop at the dummy, at x = %.2f" % player.global_position.x)
