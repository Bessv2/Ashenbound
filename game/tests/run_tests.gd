extends SceneTree
## Headless test runner. From the repository root:
##
##   godot --headless --path game --fixed-fps 60 --script res://tests/run_tests.gd
##
## --fixed-fps makes every frame advance exactly 1/60 s regardless of wall time,
## so physics tests run as fast as the CPU allows and are deterministic.
## Runs every res://tests/test_*.gd suite, or only those named in the
## TEST_SUITES environment variable (comma-separated, without ".gd"). A test fails if a check fails or if
## any engine or script error is logged while it runs. Warnings are printed
## under the test that logged them but do not fail it. Exit code 0 means every
## test passed, 1 means at least one failed.

const SUITE_DIR := "res://tests"
const ErrorCounter := preload("res://tests/framework/error_counter.gd")

var _error_counter := ErrorCounter.new()
var _warning_count := 0


func _initialize() -> void:
	OS.add_logger(_error_counter)
	# Tests never touch the real save; save tests pick their own file.
	var profile := root.get_node_or_null(^"Profile")
	if profile:
		profile.save_path = ""
	# A --script run starts with a tiny (64×64) headless window, which the
	# project's stretch mode would scale up to the base resolution. Disable the
	# scaling so pushed screen-space input maps 1:1 onto the UI under test.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	for file in _suite_files():
		var suite_script: GDScript = load(SUITE_DIR.path_join(file))
		if suite_script == null or not suite_script.can_instantiate():
			# A suite that does not parse would otherwise drop its tests silently.
			failed += 1
			print("  FAIL  %s :: (the suite does not load)" % file.get_basename())
			_error_counter.take_errors()
			continue
		for test_name in _test_names(suite_script):
			var failures := await _run_test(suite_script, test_name)
			if failures.is_empty():
				passed += 1
				print("  PASS  %s :: %s" % [file.get_basename(), test_name])
			else:
				failed += 1
				print("  FAIL  %s :: %s" % [file.get_basename(), test_name])
				for failure in failures:
					print("          - " + failure)
			for warning in _error_counter.take_warnings():
				_warning_count += 1
				print("          warning: " + warning)
	print("\n%d passed, %d failed, %d warnings" % [passed, failed, _warning_count])
	OS.remove_logger(_error_counter)
	quit(1 if failed > 0 else 0)


func _run_test(suite_script: GDScript, test_name: StringName) -> PackedStringArray:
	_reset_global_state()
	_error_counter.take_errors()
	_error_counter.take_warnings()
	var suite: Node = suite_script.new()
	root.add_child(suite)
	await suite.call(test_name)
	var failures: PackedStringArray = suite.failures
	suite.free()
	_reset_global_state()
	await process_frame
	for error in _error_counter.take_errors():
		failures.append("logged error: " + error)
	return failures


## Undoes global state a test may have changed, so tests stay independent.
func _reset_global_state() -> void:
	paused = false
	Engine.physics_ticks_per_second = 60
	GameplayActions.release_all()
	var profile := root.get_node_or_null(^"Profile")
	if profile:
		profile.save_path = ""
		profile.reset()
	# Suites test the classic look unless they choose one: the player's
	# default look and a developer's saved choice must not change them.
	var settings := root.get_node_or_null(^"Settings")
	if settings:
		settings.current.art_style = ArtStyle.Look.CLASSIC
	ArtStyle.override_look = -1


func _suite_files() -> PackedStringArray:
	var files := PackedStringArray()
	# TEST_SUITES=test_a,test_b runs only those suites (for a quick loop).
	var only := OS.get_environment("TEST_SUITES").split(",", false)
	for file in DirAccess.get_files_at(SUITE_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") \
				and (only.is_empty() or only.has(file.get_basename())):
			files.append(file)
	files.sort()
	return files


func _test_names(suite_script: GDScript) -> Array[StringName]:
	var names: Array[StringName] = []
	for method in suite_script.get_script_method_list():
		var method_name: StringName = method["name"]
		if String(method_name).begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names
