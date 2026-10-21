extends "res://tests/framework/test_case.gd"
## Tests for the Hollow's AI against the real player, on an open, navigable
## floor. Finding a way around obstacles is in test_enemy_navigation.gd.

const PlayerScene := preload("res://scenes/player/warden.tscn")
const HollowScene := preload("res://scenes/enemies/hollow.tscn")

var player: PlayerController
var hollow: EnemyController
var telegraph: AttackTelegraph


func _ready() -> void:
	add_level(80.0)
	player = PlayerScene.instantiate()
	add_child(player)


func _spawn_hollow(at: Vector3) -> void:
	hollow = HollowScene.instantiate()
	hollow.position = at
	add_child(hollow)
	telegraph = hollow.get_node("Visual/Telegraph")


func _flat_distance() -> float:
	var offset := hollow.global_position - player.global_position
	return Vector2(offset.x, offset.z).length()


func _teleport_player(to: Vector3) -> void:
	player.global_position = to
	player.reset_physics_interpolation()


func test_idles_while_the_player_is_far() -> void:
	_spawn_hollow(Vector3(0, 0, -12))
	await wait_physics_frames(30)
	check(hollow.state == EnemyController.State.IDLE, "beyond aggro range the Hollow waits")
	check_near(_flat_distance(), 12.0, 0.01, "and does not move")


func test_chases_a_player_in_range() -> void:
	_spawn_hollow(Vector3(0, 0, -6))
	await wait_physics_frames(30)
	check(hollow.state == EnemyController.State.CHASE, "within aggro range the Hollow chases")
	check(_flat_distance() < 5.0, "and closes in, now %.2f m away" % _flat_distance())


func test_stops_at_attack_range_and_hits() -> void:
	_spawn_hollow(Vector3(0, 0, -6))
	await wait_physics_frames(180)
	check(player.health.current < player.health.max_health, "the Hollow damaged the player")
	check((player.health.max_health - player.health.current) % 12 == 0, "in hits of 12")
	check(_flat_distance() >= 0.79, "no overlap with the player")
	check(_flat_distance() <= hollow.behavior.attack_range + 0.15, "stops near attack range, at %.2f m" % _flat_distance())


func _attacking() -> bool:
	return hollow.state == EnemyController.State.ATTACK


func test_telegraph_shows_during_the_windup_only() -> void:
	_spawn_hollow(Vector3(0, 0, -1.3))
	check(await wait_until(_attacking, 10), "in range: attacking")
	check(telegraph.visible, "telegraph visible during the windup")
	check(player.health.current == 100, "no damage before the windup ends")
	await wait_physics_frames(31)  # Windup is 0.5 s.
	check(not telegraph.visible, "telegraph hidden once the hit resolves")
	check(player.health.current == 88, "the hit lands for 12, health %d" % player.health.current)


func test_telegraph_covers_the_hit_area() -> void:
	_spawn_hollow(Vector3(0, 0, -1.3))
	await wait_physics_frames(2)
	var bounds := telegraph.mesh.get_aabb()
	var data := hollow.attack.data
	check_near(-bounds.position.z, data.reach, 0.01, "reaches as far as the attack")
	var half_width := data.reach * sin(deg_to_rad(data.arc_degrees * 0.5))
	check_near(bounds.size.x, half_width * 2.0, 0.02, "as wide as the attack's arc")


func test_stepping_out_of_the_telegraph_avoids_the_hit() -> void:
	_spawn_hollow(Vector3(0, 0, -1.3))
	await wait_physics_frames(5)
	_teleport_player(Vector3(0, 0, 4))
	await wait_physics_frames(40)
	check(player.health.current == 100, "dodged the hit")


func test_gives_up_when_the_player_dies() -> void:
	_spawn_hollow(Vector3(0, 0, -6))
	await wait_physics_frames(10)
	player.health.apply_damage(1000)
	await wait_physics_frames(80)  # Long enough for any attack to finish.
	check(hollow.state == EnemyController.State.IDLE, "a dead player is ignored")


func test_gives_up_beyond_the_leash() -> void:
	_spawn_hollow(Vector3(0, 0, -6))
	await wait_physics_frames(10)
	_teleport_player(Vector3(0, 0, 20))
	await wait_physics_frames(2)
	check(hollow.state == EnemyController.State.IDLE, "past the leash range the Hollow gives up")


func test_dies_sinks_and_despawns() -> void:
	_spawn_hollow(Vector3(0, 0, -6))
	var despawns := [0]
	hollow.despawned.connect(func() -> void: despawns[0] += 1)
	await wait_physics_frames(2)
	hollow.health.apply_damage(hollow.health.max_health)
	check(hollow.state == EnemyController.State.DEAD, "dead")
	await wait_physics_frames(2)
	check((hollow.get_node("CollisionShape3D") as CollisionShape3D).disabled, "a corpse does not collide")
	await wait_physics_frames(int(hollow.behavior.corpse_time * 60) + 2)
	check(despawns[0] == 1, "despawned once")
	check(not is_instance_valid(hollow), "corpse removed")


func test_death_cancels_a_pending_hit() -> void:
	_spawn_hollow(Vector3(0, 0, -1.3))
	await wait_physics_frames(5)
	check(telegraph.visible, "mid-windup")
	hollow.health.apply_damage(hollow.health.max_health)
	check(not telegraph.visible, "telegraph hidden on death")
	await wait_physics_frames(40)
	check(player.health.current == 100, "a dead Hollow's hit never lands")


func test_three_player_hits_kill_a_hollow() -> void:
	_spawn_hollow(Vector3(0, 0, -1.6))
	await wait_physics_frames(2)
	Input.action_press(GameplayActions.ATTACK)
	await wait_physics_frames(70)  # Hits at 0.12, 0.57 and 1.02 s.
	Input.action_release(GameplayActions.ATTACK)
	check(hollow.state == EnemyController.State.DEAD, "dead after three hits of 10")


func test_pause_freezes_the_hollow() -> void:
	_spawn_hollow(Vector3(0, 0, -6))
	await wait_physics_frames(10)
	get_tree().paused = true
	var at := hollow.global_position
	await wait_physics_frames(30)
	check_vector_near(hollow.global_position, at, 0.0001, "no movement while paused")


func test_chase_speed_is_frame_rate_independent() -> void:
	var distances: Array[float] = []
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		_spawn_hollow(Vector3(0, 0, -8.5))
		await wait_physics_frames(2)
		var start := _flat_distance()
		await wait_physics_frames(ticks)  # One simulated second.
		distances.append(start - _flat_distance())
		hollow.free()
	Engine.physics_ticks_per_second = 60
	for distance in distances:
		check_near(distance, distances[1], distances[1] * 0.03,
				"distance closed per second matches across tick rates %s" % [distances])
	check(distances[1] > 2.8, "about 3.2 m closed per second, got %.2f" % distances[1])
