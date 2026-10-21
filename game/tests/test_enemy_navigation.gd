extends "res://tests/framework/test_case.gd"
## Tests for how the Hollow finds its way to the player around obstacles, and
## for the navigation mesh the arena bakes at load.

const PlayerScene := preload("res://scenes/player/warden.tscn")
const HollowScene := preload("res://scenes/enemies/hollow.tscn")

## A wall across the middle of the level: 8 m wide, 1 m thick and 3 m tall.
## Steering straight from one side to the other presses into it.
const WALL := AABB(Vector3(-4.0, 0.0, -0.5), Vector3(8.0, 3.0, 1.0))

var player: PlayerController
var hollow: EnemyController


func _spawn_player(at: Vector3) -> void:
	player = PlayerScene.instantiate()
	player.position = at
	add_child(player)


func _spawn_hollow(at: Vector3, navigates: bool = true) -> void:
	hollow = HollowScene.instantiate()
	hollow.position = at
	if not navigates:
		hollow.navigation = null
	add_child(hollow)


func _teleport_player(to: Vector3) -> void:
	player.global_position = to
	player.reset_physics_interpolation()


func _player_hurt() -> bool:
	return player.health.current < player.health.max_health


func _attacking() -> bool:
	return hollow.is_attacking()


func _add_main() -> Node3D:
	var main := instantiate_main()
	add_child(main)
	return main


func test_walks_around_a_wall_to_the_player() -> void:
	check(await wait_for_navigation(add_level(30.0, [WALL])), "navigation ready")
	_spawn_player(Vector3(0, 0, 3))
	_spawn_hollow(Vector3(0, 0, -3))
	check(await wait_until(_player_hurt, 300), "went around the wall and hit the player")


func test_without_navigation_the_wall_blocks_the_chase() -> void:
	# Guards the test above: this level really defeats straight-line steering.
	check(await wait_for_navigation(add_level(30.0, [WALL])), "navigation ready")
	_spawn_player(Vector3(0, 0, 3))
	_spawn_hollow(Vector3(0, 0, -3), false)
	await wait_physics_frames(300)
	check(hollow.state == EnemyController.State.APPROACH, "still chasing")
	check(not _player_hurt(), "but never reached the player")
	check(hollow.global_position.z < WALL.position.z,
			"stuck on its own side of the wall, at %s" % hollow.global_position)


func test_replans_when_the_player_moves_behind_the_wall() -> void:
	check(await wait_for_navigation(add_level(30.0, [WALL])), "navigation ready")
	_spawn_player(Vector3(0, 0, -2))
	_spawn_hollow(Vector3(0, 0, -8))
	await wait_physics_frames(20)
	check(hollow.state == EnemyController.State.APPROACH, "chasing on the near side")
	_teleport_player(Vector3(0, 0, 3))
	check(await wait_until(_player_hurt, 360), "followed the player around the wall and hit")


func test_without_a_navigation_mesh_steers_straight_at_the_player() -> void:
	add_child(_box_body(AABB(Vector3(-15, -1, -15), Vector3(30, 1, 30))))
	_spawn_player(Vector3.ZERO)
	_spawn_hollow(Vector3(0, 0, -8))
	await wait_physics_frames(60)
	check(hollow.state == EnemyController.State.APPROACH, "chasing")
	check(hollow.global_position.z > -5.5, "closed in, now at %s" % hollow.global_position)


func test_path_following_is_frame_rate_independent() -> void:
	check(await wait_for_navigation(add_level(30.0, [WALL])), "navigation ready")
	var seconds: Array[float] = []
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		_spawn_player(Vector3(0, 0, 3))
		_spawn_hollow(Vector3(0, 0, -3))
		var frames := 0
		while not _attacking() and frames < ticks * 8:
			await get_tree().physics_frame
			frames += 1
		seconds.append(float(frames) / ticks)
		hollow.free()
		player.free()
	Engine.physics_ticks_per_second = 60
	for time in seconds:
		check_near(time, seconds[1], seconds[1] * 0.05,
				"time to reach the player around the wall matches across tick rates %s" % [seconds])
	check(seconds[1] < 5.0, "reached the player in %.2f s" % seconds[1])


func test_walks_around_a_pillar_in_the_arena() -> void:
	var main := _add_main()
	check(await wait_for_navigation(main.get_node("TestArena/Navigation")), "navigation ready")
	player = main.get_node("Player")
	# PillarNorth stands at (0, 0, -10), right between the two.
	_teleport_player(Vector3(0, 0, -7.5))
	_spawn_hollow(Vector3(0, 0, -12.5))
	check(await wait_until(_player_hurt, 300), "went around the pillar and hit the player")


func test_arena_navigation_mesh_keeps_bodies_clear_of_the_pillars() -> void:
	var main := _add_main()
	var region: NavigationRegion3D = main.get_node("TestArena/Navigation")
	check(await wait_for_navigation(region), "the arena bakes its navigation mesh at load")
	var probe: EnemyController = HollowScene.instantiate()
	var body_radius := (probe.get_node("CollisionShape3D").shape as CapsuleShape3D).radius
	probe.free()
	check(region.navigation_mesh.agent_radius >= body_radius, "baked for bodies as wide as a Hollow")
	var map := region.get_navigation_map()
	for pillar: Node3D in main.get_node("TestArena/Navigation/Pillars").get_children():
		var pillar_radius := (pillar.get_node("CollisionShape3D").shape as CylinderShape3D).radius
		var center := Vector3(pillar.global_position.x, 0.0, pillar.global_position.z)
		var nearest := NavigationServer3D.map_get_closest_point(map, center)
		var clearance := Vector2(nearest.x - center.x, nearest.z - center.z).length()
		check(clearance >= pillar_radius + body_radius,
				"%s: the nearest walkable point is %.2f m from its center" % [pillar.name, clearance])


func test_arena_navigation_mesh_is_one_floor_at_the_hollows_path_height() -> void:
	# The bake lifts the mesh above the floor it was baked from. The Hollow's
	# agent subtracts path_height_offset so path points land at its feet, where
	# its waypoint distance checks expect them. Walkable islands on pillar or
	# wall tops would also show up here.
	var main := _add_main()
	var region: NavigationRegion3D = main.get_node("TestArena/Navigation")
	var probe: EnemyController = HollowScene.instantiate()
	var height_offset := probe.navigation.path_height_offset
	probe.free()
	var vertices := region.navigation_mesh.get_vertices()
	check(not vertices.is_empty(), "the arena has a navigation mesh")
	var off_floor := 0
	for vertex in vertices:
		if absf(vertex.y - height_offset) > 0.01:
			off_floor += 1
	check(off_floor == 0, "%d of %d vertices are not %.2f m above the floor" % [off_floor, vertices.size(), height_offset])
