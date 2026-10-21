extends Node
## Base class for test suites run by res://tests/run_tests.gd.
##
## Each method whose name starts with "test_" runs on a fresh instance of the
## suite, after the instance has been added to the scene tree. Tests may await.

var failures: PackedStringArray = []


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


func wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
