extends Node
## Base class for test suites run by res://tests/run_tests.gd.
##
## Each method whose name starts with "test_" runs on a fresh instance of the
## suite, after the instance has been added to the scene tree. Tests may await.

const MainScene := preload("res://scenes/main.tscn")
const ArenaScene := preload("res://scenes/arena/test_arena.tscn")
const GroundNavigationMesh := preload("res://resources/navigation/ground_navigation_mesh.tres")

var failures: PackedStringArray = []


## A fresh, not yet added main scene playing `level` (the test arena unless
## given). Its encounters do not start by themselves unless `with_enemies` is
## true, so tests that are not about enemies run in a quiet level.
func instantiate_main(with_enemies: bool = false, level: PackedScene = ArenaScene) -> Node3D:
	var main: Node3D = MainScene.instantiate()
	main.level_scene = level
	main.use_chosen_dungeon = false
	main.encounters_start_by_themselves = with_enemies
	# Champions are random; a test that wants them turns them back on.
	main.champions_appear = false
	return main


## Adds a square floor of `floor_size` metres with its top at y = 0, plus a box
## for each of `obstacles`, all on the world physics layer, under a navigation
## region baked the way the game's levels are.
func add_level(floor_size: float, obstacles: Array[AABB] = []) -> BakedNavigationRegion:
	var region := BakedNavigationRegion.new()
	region.navigation_mesh = GroundNavigationMesh
	var half := floor_size * 0.5
	region.add_child(_box_body(AABB(Vector3(-half, -1.0, -half), Vector3(floor_size, 1.0, floor_size))))
	for box in obstacles:
		region.add_child(_box_body(box))
	add_child(region)
	return region


func _box_body(box: AABB) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.position = box.get_center()
	body.add_child(collision)
	return body


## Waits until the navigation map holding `region` can plan paths over it.
## Maps synchronize at the end of a physics frame, on a background thread.
func wait_for_navigation(region: NavigationRegion3D, max_frames: int = 30) -> bool:
	var map := region.get_navigation_map()
	var probe := region.global_position
	return await wait_until(func() -> bool:
		return NavigationServer3D.map_get_iteration_id(map) > 0 \
				and NavigationServer3D.region_get_iteration_id(region.get_rid()) > 0 \
				and NavigationServer3D.map_get_closest_point_owner(map, probe) == region.get_rid(),
			max_frames)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance,
			"%s: expected %s ± %s, got %s" % [message, expected, tolerance, actual])


func check_vector_near(actual: Variant, expected: Variant, tolerance: float, message: String) -> void:
	check(actual.distance_to(expected) <= tolerance,
			"%s: expected %s ± %s, got %s" % [message, expected, tolerance, actual])


func wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Waits until `condition` returns true, checking after each physics frame.
## Returns false if it is still false after `max_frames`.
func wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
