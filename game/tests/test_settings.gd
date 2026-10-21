extends "res://tests/framework/test_case.gd"
## Tests for GameSettings persistence and the Settings autoload.

const TEMP_PATH := "user://test_settings.cfg"
const HudScene := preload("res://ui/hud/hud.tscn")


func _exit_tree() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
	# Restore defaults so other tests see a clean Settings autoload.
	Settings.current = GameSettings.new()
	Settings.apply()


func test_round_trip_through_disk() -> void:
	var saved := GameSettings.new()
	saved.joystick_dead_zone = 0.25
	saved.joystick_sensitivity = 1.4
	saved.render_scale = 0.75
	saved.max_fps = 30
	var out := ConfigFile.new()
	saved.write_to(out)
	check(out.save(TEMP_PATH) == OK, "save should succeed")

	var config := ConfigFile.new()
	check(config.load(TEMP_PATH) == OK, "load should succeed")
	var loaded := GameSettings.new()
	loaded.read_from(config)
	check_near(loaded.joystick_dead_zone, 0.25, 0.0001, "dead zone")
	check_near(loaded.joystick_sensitivity, 1.4, 0.0001, "sensitivity")
	check_near(loaded.render_scale, 0.75, 0.0001, "render scale")
	check(loaded.max_fps == 30, "max fps")


func test_out_of_range_values_are_clamped() -> void:
	var config := ConfigFile.new()
	config.set_value(GameSettings.CONTROLS, "joystick_dead_zone", 5.0)
	config.set_value(GameSettings.GRAPHICS, "render_scale", 0.01)
	config.set_value(GameSettings.GRAPHICS, "max_fps", -10)
	var settings := GameSettings.new()
	settings.read_from(config)
	check_near(settings.joystick_dead_zone, 0.5, 0.0001, "dead zone clamped")
	check_near(settings.render_scale, 0.5, 0.0001, "render scale clamped")
	check(settings.max_fps == 0, "max fps clamped")


func test_malformed_values_keep_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value(GameSettings.CONTROLS, "joystick_sensitivity", "fast")
	config.set_value(GameSettings.GRAPHICS, "max_fps", [60])
	var settings := GameSettings.new()
	settings.read_from(config)
	check_near(settings.joystick_sensitivity, GameSettings.new().joystick_sensitivity, 0.0001, "sensitivity")
	check(settings.max_fps == GameSettings.new().max_fps, "max fps")


func test_missing_file_keeps_defaults() -> void:
	Settings.current = GameSettings.new()
	var error: Error = Settings.load_from("user://does_not_exist.cfg")
	check(error == ERR_FILE_NOT_FOUND, "missing file should report not found")
	check(Settings.current.max_fps == GameSettings.new().max_fps, "defaults kept")


func test_apply_updates_engine_and_listeners() -> void:
	var hud: Hud = HudScene.instantiate()
	add_child(hud)
	var joystick: TouchJoystick = hud.get_node("%TouchJoystick")
	Settings.current.max_fps = 45
	Settings.current.render_scale = 0.8
	Settings.current.joystick_dead_zone = 0.3
	Settings.current.joystick_sensitivity = 1.5
	Settings.apply()
	check(Engine.max_fps == 45, "Engine.max_fps")
	check_near(get_tree().root.scaling_3d_scale, 0.8, 0.0001, "3D render scale")
	check_near(joystick.dead_zone, 0.3, 0.0001, "joystick dead zone follows settings")
	check_near(joystick.sensitivity, 1.5, 0.0001, "joystick sensitivity follows settings")
