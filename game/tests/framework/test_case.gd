extends Node
## Base class for test suites run by res://tests/run_tests.gd.
##
## Each method whose name starts with "test_" runs on a fresh instance of the
## suite, after the instance has been added to the scene tree. Tests may await.

const MainScene := preload("res://scenes/main.tscn")

var failures: PackedStringArray = []


## A fresh, not yet added main scene. Enemy spawners are switched off unless
## `with_enemies` is true, so tests that are not about enemies run in a quiet
## arena.
func instantiate_main(with_enemies: bool = false) -> Node3D:
	var main: Node3D = MainScene.instantiate()
	if not with_enemies:
		for node in main.find_children("*", "Node3D", true, false):
			if node is EnemySpawner:
				node.enabled = false
	return main


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
