extends "res://tests/framework/test_case.gd"
## Tests for EnemySpawner, standalone and in the main scene.

const HollowScene := preload("res://scenes/enemies/hollow.tscn")


func _make_spawner(max_alive: int, enabled: bool = true) -> EnemySpawner:
	var spawner := EnemySpawner.new()
	spawner.enemy_scene = HollowScene
	spawner.max_alive = max_alive
	spawner.respawn_delay = 1.0
	spawner.enabled = enabled
	for point in [Vector3(10, 0, 0), Vector3(-10, 0, 0)]:
		var marker := Marker3D.new()
		marker.position = point
		spawner.add_child(marker)
	return spawner


func _player_stand_in(at: Vector3) -> Node3D:
	var stand_in := Node3D.new()
	stand_in.add_to_group(PlayerController.GROUP)
	add_child(stand_in)
	stand_in.global_position = at
	return stand_in


func test_spawns_up_to_the_limit() -> void:
	var spawner := _make_spawner(2)
	add_child(spawner)
	check(spawner.alive_count() == 2, "spawns max_alive enemies on ready")
	await wait_physics_frames(90)
	check(spawner.alive_count() == 2, "never exceeds max_alive")


func test_replaces_a_removed_enemy_after_the_delay() -> void:
	var spawner := _make_spawner(2)
	add_child(spawner)
	var first: Node3D
	for child in spawner.get_children():
		if child is EnemyController:
			first = child
			break
	first.free()
	check(spawner.alive_count() == 1, "removal is noticed")
	await wait_physics_frames(50)
	check(spawner.alive_count() == 1, "no replacement before the delay")
	await wait_physics_frames(15)  # 65 frames > 1 s.
	check(spawner.alive_count() == 2, "replaced after the delay")


func test_spawns_at_the_point_farthest_from_the_player() -> void:
	_player_stand_in(Vector3(8, 0, 0))
	var spawner := _make_spawner(1)
	add_child(spawner)
	var enemy: Node3D
	for child in spawner.get_children():
		if child is EnemyController:
			enemy = child
	check_vector_near(enemy.global_position, Vector3(-10, 0, 0), 0.01, "spawned on the far side")


func test_never_spawns_on_top_of_a_living_enemy() -> void:
	# Regression: with a player present, every spawn used to pick the same
	# farthest point, stacking enemies until physics flung them out of the arena.
	_player_stand_in(Vector3(8, 0, 0))
	var spawner := _make_spawner(2)
	add_child(spawner)
	var positions: Array[Vector3] = []
	for child in spawner.get_children():
		if child is EnemyController:
			positions.append(child.global_position)
	check(positions.size() == 2, "two enemies spawned")
	if positions.size() == 2:
		check(positions[0].distance_to(positions[1]) > EnemySpawner.CLEARANCE,
				"enemies spawned apart: %s" % [positions])


func test_disabled_spawner_does_nothing() -> void:
	var spawner := _make_spawner(3, false)
	add_child(spawner)
	await wait_physics_frames(90)
	check(spawner.alive_count() == 0, "no enemies from a disabled spawner")


func test_main_scene_spawns_hollows_only_when_asked() -> void:
	var quiet := instantiate_main()
	add_child(quiet)
	var quiet_spawner: EnemySpawner = quiet.get_node("Enemies/HollowSpawner")
	check(quiet_spawner.alive_count() == 0, "tests get a quiet arena by default")
	quiet.free()
	var busy := instantiate_main(true)
	add_child(busy)
	var busy_spawner: EnemySpawner = busy.get_node("Enemies/HollowSpawner")
	check(busy_spawner.alive_count() == busy_spawner.max_alive, "the game spawns its Hollows")
	await wait_physics_frames(120)
	for child in busy_spawner.get_children():
		if child is EnemyController:
			var at: Vector3 = child.global_position
			check(absf(at.x) < 20.0 and absf(at.z) < 20.0 and absf(at.y) < 0.1,
					"%s stays inside the arena, at %s" % [child.name, at])
